#!/bin/bash
# ComfyUI Startup Script for Blackwell GPUs (RTX 6000 Pro, B200)
# Optimized for RunPod deployment

set -e

COMFYUI_DIR="/workspace/runpod-slim/ComfyUI"
SCRIPTS_DIR="/workspace/runpod-slim/scripts"
CONFIGS_DIR="/workspace/runpod-slim/configs"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ---------------------------------------------------------------------------- #
#                          Function Definitions                                  #
# ---------------------------------------------------------------------------- #

# Setup SSH with optional key or random password
setup_ssh() {
    mkdir -p ~/.ssh

    # Generate host keys if they don't exist
    for type in rsa dsa ecdsa ed25519; do
        if [ ! -f "/etc/ssh/ssh_host_${type}_key" ]; then
            ssh-keygen -t ${type} -f "/etc/ssh/ssh_host_${type}_key" -q -N ''
        fi
    done

    # If PUBLIC_KEY is provided, use it
    if [[ $PUBLIC_KEY ]]; then
        echo "$PUBLIC_KEY" >> ~/.ssh/authorized_keys
        chmod 700 -R ~/.ssh
    else
        # Generate random password if no public key
        RANDOM_PASS=$(openssl rand -base64 12)
        echo "root:${RANDOM_PASS}" | chpasswd
        echo -e "${GREEN}Generated SSH password for root: ${RANDOM_PASS}${NC}"
    fi

    echo "PermitUserEnvironment yes" >> /etc/ssh/sshd_config
    /usr/sbin/sshd
}

# Export environment variables for shell sessions
export_env_vars() {
    echo -e "${BLUE}Exporting environment variables...${NC}"

    > /etc/rp_environment
    printenv | grep -E '^RUNPOD_|^PATH=|^CUDA|^LD_LIBRARY_PATH|^PYTHONPATH|^HF_TOKEN|^CIVITAI_API_KEY' | while read -r line; do
        name=$(echo "$line" | cut -d= -f1)
        value=$(echo "$line" | cut -d= -f2-)
        echo "export $name=\"$value\"" >> /etc/rp_environment
    done

    echo 'source /etc/rp_environment' >> ~/.bashrc
}

# Start Jupyter Lab
start_jupyter() {
    mkdir -p /workspace
    echo -e "${BLUE}Starting Jupyter Lab on port 8888...${NC}"
    nohup jupyter lab \
        --allow-root \
        --no-browser \
        --port=8888 \
        --ip=0.0.0.0 \
        --FileContentsManager.delete_to_trash=False \
        --FileContentsManager.preferred_dir=/workspace \
        --ServerApp.root_dir=/workspace \
        --ServerApp.terminado_settings='{"shell_command":["/bin/bash"]}' \
        --IdentityProvider.token="${JUPYTER_PASSWORD:-}" \
        --ServerApp.allow_origin=* &> /jupyter.log &
}

# Start FileBrowser
start_filebrowser() {
    DB_FILE="/workspace/runpod-slim/filebrowser.db"

    if [ ! -f "$DB_FILE" ]; then
        echo -e "${BLUE}Initializing FileBrowser...${NC}"
        filebrowser config init
        filebrowser config set --address 0.0.0.0
        filebrowser config set --port 8080
        filebrowser config set --root /workspace
        filebrowser config set --auth.method=json
        filebrowser users add admin adminadmin12 --perm.admin
    fi

    echo -e "${BLUE}Starting FileBrowser on port 8080...${NC}"
    nohup filebrowser &> /filebrowser.log &
}

# Detect GPU and select appropriate config
detect_gpu_config() {
    local gpu_name=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1)

    echo -e "${BLUE}Detected GPU: ${gpu_name}${NC}"

    if [[ "$gpu_name" == *"B200"* ]]; then
        echo "b200"
    elif [[ "$gpu_name" == *"6000"* ]] || [[ "$gpu_name" == *"RTX 6000"* ]]; then
        echo "rtx6000"
    elif [[ "$gpu_name" == *"5090"* ]]; then
        echo "rtx6000"  # Similar config to RTX 6000
    else
        echo "default"
    fi
}

# Setup ComfyUI arguments based on GPU
setup_comfyui_args() {
    local args_file="/workspace/runpod-slim/comfyui_args.txt"

    # Only create if doesn't exist
    if [ ! -f "$args_file" ]; then
        local gpu_type=$(detect_gpu_config)
        local config_file="${CONFIGS_DIR}/comfyui-args-${gpu_type}.txt"

        if [ -f "$config_file" ]; then
            echo -e "${GREEN}Using GPU config: ${gpu_type}${NC}"
            cp "$config_file" "$args_file"
        else
            # Fallback default config
            cat > "$args_file" << 'EOF'
# Blackwell GPU optimizations
--fast
--disable-xformers
--use-pytorch-cross-attention
--reserve-vram 0.5
--preview-method auto
--highvram
EOF
        fi
    fi
}

# Install additional custom nodes not in base image
install_extra_nodes() {
    echo -e "${BLUE}Checking for extra custom nodes...${NC}"
    cd "$COMFYUI_DIR/custom_nodes"

    local EXTRA_NODES=(
        "https://github.com/filliptm/ComfyUI_Fill-Nodes"
        "https://github.com/willmiao/ComfyUI-Lora-Manager"
        "https://github.com/DoctorDiffusion/ComfyUI-MediaMixer"
    )

    for repo in "${EXTRA_NODES[@]}"; do
        local repo_name=$(basename "$repo")
        if [ ! -d "$repo_name" ]; then
            echo -e "${YELLOW}  Installing $repo_name...${NC}"
            git clone --depth 1 "$repo" 2>/dev/null || true
        fi
    done
}

# Install dependencies for custom nodes
install_node_dependencies() {
    echo -e "${BLUE}Installing custom node dependencies...${NC}"
    cd "$COMFYUI_DIR/custom_nodes"

    for node_dir in */; do
        if [ -d "$node_dir" ]; then
            cd "$COMFYUI_DIR/custom_nodes/$node_dir"

            if [ -f "requirements.txt" ]; then
                pip install -q --no-cache-dir -r requirements.txt 2>/dev/null || true
            fi

            if [ -f "install.py" ]; then
                python install.py 2>/dev/null || true
            fi
        fi
    done
}

# Install optimized attention packages if not present (compiled on pod for speed)
install_attention_packages() {
    echo -e "${BLUE}Checking attention packages...${NC}"

    # Check Flash Attention
    if ! python -c "import flash_attn" 2>/dev/null; then
        echo -e "${YELLOW}  Installing Flash Attention (this may take a few minutes)...${NC}"
        pip install flash-attn --no-build-isolation 2>/dev/null || \
            echo -e "${YELLOW}  Flash Attention not available for this CUDA version${NC}"
    else
        echo -e "${GREEN}  Flash Attention: ✓${NC}"
    fi

    # Check SageAttention
    if ! python -c "import sageattention" 2>/dev/null; then
        echo -e "${YELLOW}  Installing SageAttention...${NC}"
        pip install sageattention --no-build-isolation 2>/dev/null || \
            echo -e "${YELLOW}  SageAttention not available${NC}"
    else
        echo -e "${GREEN}  SageAttention: ✓${NC}"
    fi
}

# ---------------------------------------------------------------------------- #
#                               Main Program                                     #
# ---------------------------------------------------------------------------- #

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  ComfyUI Blackwell Startup${NC}"
echo -e "${GREEN}========================================${NC}"

# Setup environment
setup_ssh
export_env_vars

# Start services
start_filebrowser
start_jupyter

# Create workspace directories
mkdir -p /workspace/runpod-slim

# Copy scripts from image if not in workspace (first boot)
if [ ! -d "$SCRIPTS_DIR" ]; then
    echo -e "${YELLOW}Copying scripts to workspace...${NC}"
    cp -r /opt/runpod-scripts "$SCRIPTS_DIR"
    chmod +x "$SCRIPTS_DIR"/*.sh
fi

# Copy configs from image if not in workspace (first boot)
if [ ! -d "$CONFIGS_DIR" ]; then
    echo -e "${YELLOW}Copying configs to workspace...${NC}"
    cp -r /opt/runpod-configs "$CONFIGS_DIR"
fi

# Copy ComfyUI from image if not in workspace (first boot)
if [ ! -d "$COMFYUI_DIR" ]; then
    echo -e "${YELLOW}First boot: Copying ComfyUI to workspace...${NC}"
    cp -r /app/ComfyUI "$COMFYUI_DIR"
fi

# Create model directories
mkdir -p "$COMFYUI_DIR/models/diffusion_models"
mkdir -p "$COMFYUI_DIR/models/text_encoders"
mkdir -p "$COMFYUI_DIR/models/vae"
mkdir -p "$COMFYUI_DIR/models/loras/LTXV2"
mkdir -p "$COMFYUI_DIR/models/loras/Wan Video 2.2 T2V 14B"
mkdir -p "$COMFYUI_DIR/models/clip_vision"
mkdir -p "$COMFYUI_DIR/models/upscale_models"
mkdir -p "$COMFYUI_DIR/models/rife"
mkdir -p "$COMFYUI_DIR/models/LLM/GGUF"

# Install extra custom nodes
install_extra_nodes

# Install custom node dependencies
install_node_dependencies

# Install optimized attention packages (if not in base image)
install_attention_packages

# Setup GPU-specific ComfyUI arguments
setup_comfyui_args

# Read custom arguments
ARGS_FILE="/workspace/runpod-slim/comfyui_args.txt"
FIXED_ARGS="--listen 0.0.0.0 --port 8188"
CUSTOM_ARGS=""

if [ -s "$ARGS_FILE" ]; then
    CUSTOM_ARGS=$(grep -v '^#' "$ARGS_FILE" | grep -v '^$' | tr '\n' ' ')
fi

# Start ComfyUI
cd $COMFYUI_DIR
echo -e "${GREEN}Starting ComfyUI...${NC}"
if [ ! -z "$CUSTOM_ARGS" ]; then
    echo -e "${BLUE}Arguments: $FIXED_ARGS $CUSTOM_ARGS${NC}"
    nohup python main.py $FIXED_ARGS $CUSTOM_ARGS &> /workspace/runpod-slim/comfyui.log &
else
    nohup python main.py $FIXED_ARGS &> /workspace/runpod-slim/comfyui.log &
fi

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Services Started${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${BLUE}ComfyUI:${NC}     http://localhost:8188"
echo -e "${BLUE}FileBrowser:${NC} http://localhost:8080 (admin/adminadmin12)"
echo -e "${BLUE}Jupyter:${NC}     http://localhost:8888"
echo ""
echo -e "${YELLOW}To download models, run:${NC}"
echo "  cd /workspace/runpod-slim/scripts"
echo "  ./download-models.sh ltx2       # LTX-2 only"
echo "  ./download-models.sh wan22      # WAN 2.2 only"
echo "  ./download-models.sh -f all     # All models (fast)"
echo ""

# Tail the log file
tail -f /workspace/runpod-slim/comfyui.log
