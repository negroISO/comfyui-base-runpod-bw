#!/bin/bash
# Shared functions for model downloading
# Source this file in other download scripts

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Auto-detect ComfyUI location
detect_comfyui() {
    local paths=(
        "/workspace/runpod-slim/ComfyUI"
        "/workspace/ComfyUI"
        "/app/ComfyUI"
        "/ComfyUI"
    )

    for path in "${paths[@]}"; do
        if [ -d "$path" ]; then
            echo "$path"
            return 0
        fi
    done

    echo ""
    return 1
}

# Initialize paths
init_paths() {
    COMFY_BASE=$(detect_comfyui)
    if [ -z "$COMFY_BASE" ]; then
        echo -e "${RED}ERROR: Could not find ComfyUI directory${NC}"
        exit 1
    fi

    export COMFY_BASE
    export MODELS_DIR="${COMFY_BASE}/models"
    export DIFFUSION_DIR="${MODELS_DIR}/diffusion_models"
    export UNET_DIR="${MODELS_DIR}/unet"
    export TEXT_ENCODER_DIR="${MODELS_DIR}/text_encoders"
    export CLIP_DIR="${MODELS_DIR}/clip"
    export VAE_DIR="${MODELS_DIR}/vae"
    export LORAS_DIR="${MODELS_DIR}/loras"
    export UPSCALE_DIR="${MODELS_DIR}/upscale_models"
    export CLIP_VISION_DIR="${MODELS_DIR}/clip_vision"
    export CUSTOM_NODES_DIR="${COMFY_BASE}/custom_nodes"

    # Activate venv if exists
    VENV_DIR="${COMFY_BASE}/.venv"
    if [ -d "$VENV_DIR" ]; then
        source "$VENV_DIR/bin/activate"
    fi

    echo -e "${GREEN}ComfyUI found at: ${COMFY_BASE}${NC}"
}

# Create all model directories
create_model_dirs() {
    echo -e "${YELLOW}Creating model directories...${NC}"
    mkdir -p "$DIFFUSION_DIR" "$UNET_DIR" "$TEXT_ENCODER_DIR" "$CLIP_DIR"
    mkdir -p "$VAE_DIR" "$LORAS_DIR" "$UPSCALE_DIR" "$CLIP_VISION_DIR"
    mkdir -p "${MODELS_DIR}/LLM/GGUF"
    mkdir -p "${MODELS_DIR}/rife"
    mkdir -p "${MODELS_DIR}/latent_upscale_models"
}

# Check if aria2c is available, prefer it for speed
setup_downloader() {
    if command -v aria2c &> /dev/null; then
        DOWNLOADER="aria2c"
        echo -e "${GREEN}Using aria2c for parallel downloads${NC}"
    else
        DOWNLOADER="wget"
        echo -e "${YELLOW}aria2c not found, using wget (slower)${NC}"
        echo -e "${YELLOW}Install with: apt-get install -y aria2${NC}"
    fi
}

# Install aria2 if not present
install_aria2() {
    if ! command -v aria2c &> /dev/null; then
        echo -e "${YELLOW}Installing aria2 for faster downloads...${NC}"
        apt-get update -qq && apt-get install -y -qq aria2
    fi
}

# Setup HuggingFace authentication
setup_hf_auth() {
    echo -e "${BLUE}Checking API keys...${NC}"

    if [ -n "$HF_TOKEN" ]; then
        # Also setup hf CLI for fallback
        if ! command -v hf &> /dev/null; then
            pip install -q huggingface_hub[cli]
        fi
        hf login --token "$HF_TOKEN" --add-to-git-credential 2>/dev/null || true
        echo -e "${GREEN}  HF_TOKEN: ✓ Set (authenticated downloads, no rate limits)${NC}"
    else
        echo -e "${YELLOW}  HF_TOKEN: ✗ Not set (downloads may be rate-limited)${NC}"
        echo -e "${YELLOW}    Set in RunPod: Template > Environment Variables > HF_TOKEN${NC}"
    fi

    if [ -n "$CIVITAI_API_KEY" ]; then
        echo -e "${GREEN}  CIVITAI_API_KEY: ✓ Set (can download premium models)${NC}"
    else
        echo -e "${YELLOW}  CIVITAI_API_KEY: ✗ Not set (Civitai models will be skipped)${NC}"
        echo -e "${YELLOW}    Set in RunPod: Template > Environment Variables > CIVITAI_API_KEY${NC}"
    fi
    echo ""
}

# Generic download function with progress
# Uses aria2c with 16 parallel connections for maximum speed
download_file() {
    local url="$1"
    local output="$2"
    local name="$3"
    local auth_header="$4"  # Optional: "Authorization: Bearer TOKEN"

    if [ -f "$output" ]; then
        echo -e "${YELLOW}  [SKIP] $name already exists${NC}"
        return 0
    fi

    local dir=$(dirname "$output")
    mkdir -p "$dir"

    echo -e "${BLUE}  Downloading: $name${NC}"

    local success=false

    if [ "$DOWNLOADER" = "aria2c" ]; then
        if [ -n "$auth_header" ]; then
            aria2c -x 16 -s 16 -k 1M --file-allocation=none --console-log-level=warn \
                --header="$auth_header" \
                -d "$dir" -o "$(basename "$output")" "$url" 2>/dev/null && success=true
        else
            aria2c -x 16 -s 16 -k 1M --file-allocation=none --console-log-level=warn \
                -d "$dir" -o "$(basename "$output")" "$url" 2>/dev/null && success=true
        fi
    else
        if [ -n "$auth_header" ]; then
            wget -q --show-progress --header="$auth_header" -O "$output" "$url" && success=true
        else
            wget -q --show-progress -O "$output" "$url" && success=true
        fi
    fi

    if [ "$success" = true ] && [ -f "$output" ]; then
        local size=$(stat -c%s "$output" 2>/dev/null || stat -f%z "$output" 2>/dev/null || echo "0")
        if [ "$size" -gt 1000 ]; then
            echo -e "${GREEN}  [OK] $name${NC}"
            return 0
        fi
    fi

    echo -e "${RED}  [FAILED] $name${NC}"
    rm -f "$output" 2>/dev/null
    return 1
}

# Download from HuggingFace
# Prefers aria2c with auth token for 16x parallel download speed
hf_download() {
    local repo="$1"
    local file="$2"
    local output_dir="$3"
    local name="$4"

    local filename=$(basename "$file")
    local output_file="${output_dir}/${filename}"

    if [ -f "$output_file" ]; then
        echo -e "${YELLOW}  [SKIP] $name already exists${NC}"
        return 0
    fi

    mkdir -p "$output_dir"

    local url="https://huggingface.co/${repo}/resolve/main/${file}"
    local auth_header=""

    # Use HF_TOKEN for authenticated downloads (faster, no rate limits)
    if [ -n "$HF_TOKEN" ]; then
        auth_header="Authorization: Bearer $HF_TOKEN"
    fi

    # Prefer aria2c for speed, fall back to hf CLI, then wget
    if [ "$DOWNLOADER" = "aria2c" ]; then
        download_file "$url" "$output_file" "$name" "$auth_header"
    elif command -v hf &> /dev/null && [ -n "$HF_TOKEN" ]; then
        echo -e "${BLUE}  Downloading: $name${NC}"
        hf download "$repo" "$file" --local-dir "$output_dir" --local-dir-use-symlinks False 2>/dev/null
    else
        download_file "$url" "$output_file" "$name" "$auth_header"
    fi

    # Handle nested directories from hf download
    if [ -f "${output_dir}/${file}" ] && [ "${output_dir}/${file}" != "$output_file" ]; then
        mv "${output_dir}/${file}" "$output_file"
        # Clean up empty parent dirs
        local parent=$(dirname "${output_dir}/${file}")
        while [ "$parent" != "$output_dir" ]; do
            rmdir "$parent" 2>/dev/null || break
            parent=$(dirname "$parent")
        done
    fi

    if [ -f "$output_file" ]; then
        local size=$(stat -c%s "$output_file" 2>/dev/null || stat -f%z "$output_file" 2>/dev/null || echo "0")
        if [ "$size" -gt 1000 ]; then
            return 0
        fi
    fi

    echo -e "${RED}  [FAILED] $name${NC}"
    return 1
}

# Download from Civitai with API key
civitai_download() {
    local model_version_id="$1"
    local output="$2"
    local name="$3"

    if [ -f "$output" ]; then
        echo -e "${YELLOW}  [SKIP] $name already exists${NC}"
        return 0
    fi

    if [ -z "$CIVITAI_API_KEY" ]; then
        echo -e "${RED}  [SKIP] $name - CIVITAI_API_KEY not set${NC}"
        return 1
    fi

    local url="https://civitai.com/api/download/models/${model_version_id}?token=${CIVITAI_API_KEY}"
    download_file "$url" "$output" "$name"
}

# Create symlink or copy as fallback
link_or_copy() {
    local source="$1"
    local dest="$2"

    if [ ! -f "$source" ]; then
        return 1
    fi

    if [ -f "$dest" ]; then
        return 0
    fi

    mkdir -p "$(dirname "$dest")"
    ln -sf "$source" "$dest" 2>/dev/null || cp "$source" "$dest"
}

# Print section header
section() {
    echo ""
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}  $1${NC}"
    echo -e "${CYAN}========================================${NC}"
}

# Print summary
print_summary() {
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}  DOWNLOAD COMPLETE${NC}"
    echo -e "${GREEN}========================================${NC}"
}
