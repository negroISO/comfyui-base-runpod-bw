#!/bin/bash
# Install optimized AI packages for Blackwell GPUs (Linux)
# These provide significant performance improvements for video generation

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Installing Optimized AI Packages${NC}"
echo -e "${BLUE}  For Blackwell GPUs (CUDA 12.8+)${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Detect CUDA version
CUDA_VERSION=$(nvcc --version 2>/dev/null | grep "release" | sed 's/.*release //' | sed 's/,.*//' || echo "unknown")
echo -e "${GREEN}Detected CUDA: ${CUDA_VERSION}${NC}"

# Detect GPU
GPU_NAME=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1 || echo "unknown")
echo -e "${GREEN}Detected GPU: ${GPU_NAME}${NC}"
echo ""

# Install build dependencies
echo -e "${YELLOW}[1/8] Installing build dependencies...${NC}"
pip install -q --upgrade pip setuptools wheel
pip install -q packaging psutil ninja

# ============================================
# PyTorch (should already be installed, but ensure CUDA 12.8)
# ============================================
echo -e "${YELLOW}[2/8] Checking PyTorch installation...${NC}"
TORCH_CUDA=$(python -c "import torch; print(torch.version.cuda)" 2>/dev/null || echo "none")
echo -e "${GREEN}PyTorch CUDA version: ${TORCH_CUDA}${NC}"

if [[ "$TORCH_CUDA" != "12.8"* ]]; then
    echo -e "${YELLOW}Upgrading PyTorch to CUDA 12.8...${NC}"
    pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu128
fi

# ============================================
# Triton (required for Flash Attention, SageAttention)
# ============================================
echo -e "${YELLOW}[3/8] Installing Triton...${NC}"
pip install -q triton>=3.0.0

# ============================================
# Flash Attention 2 (critical for video models)
# ============================================
echo -e "${YELLOW}[4/8] Installing Flash Attention 2...${NC}"
echo -e "${BLUE}This may take 3-5 minutes to compile...${NC}"

# Set reasonable parallel jobs to avoid OOM during compilation
export MAX_JOBS=${MAX_JOBS:-4}

pip install flash-attn --no-build-isolation 2>/dev/null || {
    echo -e "${YELLOW}Pre-built wheel failed, trying with ninja...${NC}"
    pip install ninja
    MAX_JOBS=4 pip install flash-attn --no-build-isolation
}

# ============================================
# SageAttention 2 (optimized for Blackwell)
# ============================================
echo -e "${YELLOW}[5/8] Installing SageAttention 2...${NC}"
echo -e "${BLUE}SageAttention 2.2+ has specific Blackwell optimizations${NC}"

pip install sageattention --no-build-isolation 2>/dev/null || {
    echo -e "${YELLOW}Pip install failed, building from source...${NC}"
    cd /tmp
    git clone --depth 1 https://github.com/thu-ml/SageAttention.git
    cd SageAttention
    export EXT_PARALLEL=4 NVCC_APPEND_FLAGS="--threads 4" MAX_JOBS=4
    pip install . --no-build-isolation
    cd /
    rm -rf /tmp/SageAttention
}

# ============================================
# xformers (memory-efficient attention)
# ============================================
echo -e "${YELLOW}[6/8] Installing xformers...${NC}"

# Try official wheel first
pip install -q xformers --index-url https://download.pytorch.org/whl/cu128 2>/dev/null || \
pip install -q xformers --index-url https://download.pytorch.org/whl/cu124 2>/dev/null || \
pip install -q xformers 2>/dev/null || {
    echo -e "${YELLOW}No pre-built xformers wheel, building from source...${NC}"
    pip install -v -U xformers --no-build-isolation
}

# ============================================
# bitsandbytes (quantization)
# ============================================
echo -e "${YELLOW}[7/10] Installing bitsandbytes...${NC}"
pip install -q bitsandbytes

# ============================================
# Nunchaku INT4/FP4 Kernels
# ============================================
echo -e "${YELLOW}[8/10] Installing Nunchaku INT4/FP4 kernels...${NC}"

# Detect GPU compute capability for FP4 support
GPU_SM=$(nvidia-smi --query-gpu=compute_cap --format=csv,noheader 2>/dev/null | head -1 | tr -d '.' || echo "0")
echo -e "${BLUE}GPU Compute Capability: sm${GPU_SM}${NC}"

# Check CUDA version for appropriate wheel
if [[ "$CUDA_VERSION" == "13"* ]]; then
    # CUDA 13 - use PyTorch 2.10 wheels
    echo -e "${GREEN}Using Nunchaku for CUDA 13 / PyTorch 2.10${NC}"
    pip install https://github.com/nunchaku-ai/nunchaku/releases/download/v1.2.1/nunchaku-1.2.1+cu13.0torch2.10-cp311-cp311-linux_x86_64.whl 2>/dev/null || \
    pip install https://github.com/deepbeepmeep/kernels/releases/download/v1.2.0_Nunchaku/nunchaku-1.2.0+torch2.7-cp310-cp310-linux_x86_64.whl 2>/dev/null || \
    echo -e "${YELLOW}Nunchaku wheel install failed, trying pip...${NC}" && pip install nunchaku 2>/dev/null || true
else
    # CUDA 12.8 - use PyTorch 2.7.1 wheels
    echo -e "${GREEN}Using Nunchaku for CUDA 12.8 / PyTorch 2.7.1${NC}"
    pip install https://github.com/deepbeepmeep/kernels/releases/download/v1.2.0_Nunchaku/nunchaku-1.2.0+torch2.7-cp310-cp310-linux_x86_64.whl 2>/dev/null || \
    pip install nunchaku 2>/dev/null || true
fi

# ============================================
# Light2xv NVP4 Kernels (RTX 50xx / sm120+ only)
# ============================================
echo -e "${YELLOW}[9/10] Checking Light2xv NVP4 kernels...${NC}"

if [[ "$GPU_SM" -ge "120" ]]; then
    echo -e "${GREEN}RTX 50xx (sm120+) detected - installing Light2xv FP4 kernels${NC}"
    pip install https://github.com/deepbeepmeep/kernels/releases/download/Light2xv/lightx2v_kernel-0.0.2+torch2.10.0-cp311-abi3-linux_x86_64.whl 2>/dev/null || {
        echo -e "${YELLOW}Light2xv wheel failed, FP4 may not be available${NC}"
    }
else
    echo -e "${YELLOW}GPU is not sm120+ (RTX 50xx) - skipping Light2xv FP4 kernels${NC}"
    echo -e "${BLUE}Note: FP4 quantization requires RTX 50xx series GPUs${NC}"
fi

# ============================================
# Additional optimizations
# ============================================
echo -e "${YELLOW}[10/10] Installing additional packages...${NC}"

# Accelerate for distributed training
pip install -q accelerate

# Optimum for inference optimization
pip install -q optimum

# ONNX Runtime with CUDA
pip install -q onnxruntime-gpu 2>/dev/null || true

# Verify installations
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Installation Complete${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

echo -e "${BLUE}Installed packages:${NC}"
python -c "
import sys
packages = ['torch', 'triton', 'flash_attn', 'sageattention', 'xformers', 'bitsandbytes', 'nunchaku', 'lightx2v_kernel']
for pkg in packages:
    try:
        mod = __import__(pkg.replace('-', '_'))
        ver = getattr(mod, '__version__', 'installed')
        print(f'  {pkg}: {ver}')
    except ImportError:
        if pkg in ['nunchaku', 'lightx2v_kernel']:
            print(f'  {pkg}: not installed (optional)')
        else:
            print(f'  {pkg}: NOT INSTALLED')
"

echo ""
echo -e "${BLUE}INT4/FP4 Quantization Support:${NC}"
python -c "
try:
    import nunchaku
    print('  Nunchaku INT4/FP4: available')
except:
    print('  Nunchaku INT4/FP4: not available')
try:
    import lightx2v_kernel
    print('  Light2xv FP4 (sm120+): available')
except:
    print('  Light2xv FP4 (sm120+): not available (requires RTX 50xx)')
"

echo ""
echo -e "${BLUE}PyTorch CUDA info:${NC}"
python -c "
import torch
print(f'  PyTorch: {torch.__version__}')
print(f'  CUDA available: {torch.cuda.is_available()}')
print(f'  CUDA version: {torch.version.cuda}')
if torch.cuda.is_available():
    print(f'  GPU: {torch.cuda.get_device_name(0)}')
    print(f'  VRAM: {torch.cuda.get_device_properties(0).total_memory / 1024**3:.1f} GB')
"

echo ""
echo -e "${YELLOW}Restart ComfyUI to use the new packages:${NC}"
echo "  /workspace/runpod-slim/scripts/restart-comfyui.sh"
