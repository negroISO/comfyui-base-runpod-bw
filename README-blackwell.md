# ComfyUI Base for Blackwell GPUs

Optimized ComfyUI deployment for NVIDIA Blackwell architecture GPUs:
- **RTX 6000 Pro** (48GB VRAM)
- **B200** (192GB VRAM)
- **RTX 5090** (32GB VRAM)

## Features

- **CUDA 12.8** for Blackwell architecture support
- **GPU auto-detection** with optimized configs per GPU type
- **Modular model downloads** - download only what you need
- **Pre-installed custom nodes** for video generation workflows
- **Fast parallel downloads** with aria2
- **Optimized AI packages** pre-installed:
  - Flash Attention 2 (2.8+) - critical for video models
  - SageAttention 2 (2.2+) - Blackwell-specific optimizations
  - xformers - memory-efficient attention
  - Triton - custom CUDA kernels
  - bitsandbytes - quantization support

## Quick Start (RunPod)

### 1. Deploy the Template

Use the Docker image or build your own:

```bash
# Build the image
docker build -f Dockerfile.blackwell -t comfyui-blackwell .

# Or use pre-built (if available)
docker pull ghcr.io/negroiso/comfyui-blackwell:latest
```

### 2. Access Services

| Service | Port | Credentials |
|---------|------|-------------|
| ComfyUI | 8188 | - |
| FileBrowser | 8080 | admin / adminadmin12 |
| Jupyter | 8888 | Set via `JUPYTER_PASSWORD` |
| SSH | 22 | Random password in logs |

### 3. Download Models

SSH into your pod or use Jupyter terminal:

```bash
cd /workspace/runpod-slim/scripts

# Set API keys for faster downloads
export HF_TOKEN="your_huggingface_token"
export CIVITAI_API_KEY="your_civitai_key"

# Download specific model sets
./download-models.sh ltx2        # LTX-2 only (~80GB)
./download-models.sh wan22       # WAN 2.2 only (~100GB)
./download-models.sh hunyuan     # HunyuanVideo 1.5 (~43GB)
./download-models.sh extras      # Ditto, Z-Image, etc. (~30GB)

# Download everything (with fast parallel downloads)
./download-models.sh -f all      # All models (~250GB)
```

## Model Sets

### LTX-2 (`ltx2`)
- Phr00t V62 Merge (primary model)
- Official Dev FP8, Distilled FP8, FP4
- Gemma 3 12B text encoders (multiple precisions)
- Video/Audio VAEs
- Control LoRAs (Canny, Depth, Pose, Detailer, Camera)

### WAN 2.2 (`wan22`)
- I2V High/Low noise models
- T2V High/Low noise models
- SVI v2 PRO, Lightning, LightX2V LoRAs
- NSFW variants (SVI cf, DaSiWa, French Kiss, Remix)
- GGUF models for VRAM efficiency
- RIFE 4.9 interpolation
- 2x upscaler

### HunyuanVideo 1.5 (`hunyuan`)
- 720p I2V model
- 1080p SR Distilled model
- Latent upsampler
- Text encoders (ByT5, Qwen 2.5 VL 7B)
- SigCLIP vision encoder

### Extras (`extras`)
- Z-Image Turbo
- Qwen Image Edit
- Ditto video editing (Sim2Real, Global Style)
- MelBandRoformer (audio separation)
- Qwen3-VL GGUF models

## GPU Configurations

The startup script auto-detects your GPU and applies optimized settings:

### RTX 6000 Pro (48GB)
```
--fast --cuda-malloc --cuda-stream --reserve-vram 0.5 --highvram
```

### B200 (192GB)
```
--fast --cuda-malloc --cuda-stream --reserve-vram 1.0 --highvram --max-batch-size 8
```

### Custom Configuration
Edit `/workspace/runpod-slim/comfyui_args.txt`:
```bash
# Your custom args here
--fast
--cuda-malloc
--preview-method auto
```

## Directory Structure

```
/workspace/runpod-slim/
├── ComfyUI/
│   ├── models/
│   │   ├── diffusion_models/    # Main models
│   │   ├── text_encoders/       # Text encoders
│   │   ├── vae/                 # VAE models
│   │   ├── loras/               # LoRA models
│   │   │   ├── LTXV2/           # LTX-2 custom LoRAs
│   │   │   └── Wan Video 2.2*/  # WAN 2.2 custom LoRAs
│   │   └── ...
│   └── custom_nodes/
├── scripts/
│   ├── download-models.sh       # Master download script
│   ├── download-ltx2.sh
│   ├── download-wan22.sh
│   ├── download-hunyuan.sh
│   └── download-extras.sh
├── configs/
│   ├── comfyui-args-rtx6000.txt
│   ├── comfyui-args-b200.txt
│   └── comfyui-args-default.txt
├── comfyui_args.txt             # Active config
└── comfyui.log                  # ComfyUI logs
```

## Environment Variables

| Variable | Description |
|----------|-------------|
| `HF_TOKEN` | HuggingFace token for authenticated downloads |
| `CIVITAI_API_KEY` | Civitai API key for premium models |
| `JUPYTER_PASSWORD` | Jupyter Lab password |
| `PUBLIC_KEY` | SSH public key for key-based auth |

Set these in RunPod's environment variables or export before running scripts.

## Pre-installed Custom Nodes

- ComfyUI-Manager
- ComfyUI-KJNodes
- Civicomfy
- ComfyUI-RunpodDirect
- ComfyUI-LTXVideo
- ComfyUI-VideoHelperSuite
- ComfyUI-GGUF
- rgthree-comfy

## Optimized AI Packages

These packages are pre-installed for maximum performance on Blackwell GPUs:

| Package | Version | Purpose |
|---------|---------|---------|
| Flash Attention 2 | 2.8+ | Fast attention for video models |
| SageAttention 2 | 2.2+ | Blackwell-optimized attention (CUDA 12.8+) |
| xformers | 0.0.28+ | Memory-efficient attention |
| Triton | 3.0+ | Custom CUDA kernel compilation |
| bitsandbytes | 0.44+ | Quantization for lower VRAM |
| accelerate | 1.0+ | Distributed training/inference |

To reinstall or update these packages:
```bash
cd /workspace/runpod-slim/scripts
./install-optimized-packages.sh
```

Or manually:
```bash
pip install flash-attn --no-build-isolation
pip install sageattention --no-build-isolation
pip install xformers bitsandbytes accelerate
```

## Troubleshooting

### Models not loading
```bash
# Check ComfyUI logs
tail -f /workspace/runpod-slim/comfyui.log

# Restart ComfyUI
pkill -f 'python.*main.py'
cd /workspace/runpod-slim/ComfyUI
source .venv/bin/activate
python main.py --listen 0.0.0.0 --port 8188 &
```

### Download failures
```bash
# Use aria2 for better reliability
./download-models.sh -f ltx2

# Check disk space
df -h /workspace
```

### VRAM issues
Edit `/workspace/runpod-slim/comfyui_args.txt`:
```bash
# For lower VRAM, remove --highvram and add:
--lowvram
# Or for medium VRAM:
--normalvram
```

## Building the Docker Image

```bash
# Clone the repo
git clone https://github.com/negroISO/comfyui-base-runpod-bw.git
cd comfyui-base-runpod-bw

# Build for Blackwell
docker build -f Dockerfile.blackwell -t comfyui-blackwell .

# Push to registry
docker tag comfyui-blackwell ghcr.io/negroiso/comfyui-blackwell:latest
docker push ghcr.io/negroiso/comfyui-blackwell:latest
```

## Credits

- Based on [runpod-workers/comfyui-base](https://github.com/runpod-workers/comfyui-base)
- LTX-2 models by [Lightricks](https://huggingface.co/Lightricks)
- WAN 2.2 models by [Comfy-Org](https://huggingface.co/Comfy-Org)
- Community models by Phr00t, Kijai, FX-FeiHou, and others

## License

GPL-3.0 (same as upstream)
