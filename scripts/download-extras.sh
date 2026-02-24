#!/bin/bash
# Extra Models Download Script
# Downloads Z-Image Turbo, Qwen, Ditto, and other utility models

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/download-base.sh"

# Initialize
init_paths
setup_downloader
setup_hf_auth
create_model_dirs

section "Z-Image Turbo Models"

# Diffusion model
hf_download "Comfy-Org/z_image_turbo" "split_files/diffusion_models/z_image_turbo_bf16.safetensors" "$DIFFUSION_DIR" "Z-Image Turbo BF16"

# VAE
hf_download "Comfy-Org/z_image_turbo" "split_files/vae/ae.safetensors" "$VAE_DIR" "Z-Image Turbo VAE"

# Text encoder
hf_download "Comfy-Org/z_image_turbo" "split_files/text_encoders/qwen_3_4b.safetensors" "$TEXT_ENCODER_DIR" "Qwen 3 4B"

# Move nested files
for dir in "$DIFFUSION_DIR" "$VAE_DIR" "$TEXT_ENCODER_DIR"; do
    find "${dir}/split_files" -name "*.safetensors" -exec mv {} "${dir}/" \; 2>/dev/null || true
    rm -rf "${dir}/split_files" 2>/dev/null || true
done

section "Qwen Image Models"

hf_download "aidiffuser/Qwen-Image-Edit-2509" "Qwen-Image-Edit-2509_fp8_e4m3fn.safetensors" "$DIFFUSION_DIR" "Qwen Image Edit 2509"
hf_download "UmeAiRT/ComfyUI-Auto_installer" "models/clip/qwen_2.5_vl_7b.safetensors" "$TEXT_ENCODER_DIR" "Qwen 2.5 VL 7B"

# Move nested files
if [ -f "${TEXT_ENCODER_DIR}/models/clip/qwen_2.5_vl_7b.safetensors" ]; then
    mv "${TEXT_ENCODER_DIR}/models/clip/qwen_2.5_vl_7b.safetensors" "${TEXT_ENCODER_DIR}/"
    rm -rf "${TEXT_ENCODER_DIR}/models" 2>/dev/null || true
fi

section "Ditto Video Editing Models"

hf_download "QingyanBai/Ditto_models" "models_comfy/ditto_sim2real_comfy.safetensors" "$DIFFUSION_DIR" "Ditto Sim2Real"
hf_download "QingyanBai/Ditto_models" "models_comfy/ditto_global_style_comfy.safetensors" "$DIFFUSION_DIR" "Ditto Global Style"
hf_download "QingyanBai/Ditto_models" "models_comfy/ditto_global_comfy.safetensors" "$DIFFUSION_DIR" "Ditto Global"

# Move nested files
if ls "${DIFFUSION_DIR}/models_comfy/"*.safetensors 1>/dev/null 2>&1; then
    mv "${DIFFUSION_DIR}/models_comfy/"*.safetensors "${DIFFUSION_DIR}/"
fi
rm -rf "${DIFFUSION_DIR}/models_comfy" 2>/dev/null || true

section "MelBandRoFormer (Audio Separation)"

hf_download "Kijai/MelBandRoFormer_comfy" "MelBandRoformer_fp16.safetensors" "$DIFFUSION_DIR" "MelBandRoformer"

section "Qwen3-VL GGUF Models (Vision-Language)"

LLM_DIR="${MODELS_DIR}/LLM/GGUF"

# 8B v3 model
QWEN3_8B_DIR="${LLM_DIR}/mradermacher/Qwen3-VL-8B-Instruct-c_abliterated-v3-GGUF"
mkdir -p "$QWEN3_8B_DIR"
download_file "https://huggingface.co/mradermacher/Qwen3-VL-8B-Instruct-c_abliterated-v3-GGUF/resolve/main/Qwen3-VL-8B-Instruct-c_abliterated-v3.Q8_0.gguf" \
    "${QWEN3_8B_DIR}/Qwen3-VL-8B-Instruct-c_abliterated-v3.Q8_0.gguf" "Qwen3-VL 8B GGUF"

# 4B v2 model
QWEN3_4B_DIR="${LLM_DIR}/mradermacher/Qwen3-VL-4B-Instruct-c_abliterated-v2-GGUF"
mkdir -p "$QWEN3_4B_DIR"
download_file "https://huggingface.co/mradermacher/Qwen3-VL-4B-Instruct-c_abliterated-v2-GGUF/resolve/main/Qwen3-VL-4B-Instruct-c_abliterated-v2.Q8_0.gguf" \
    "${QWEN3_4B_DIR}/Qwen3-VL-4B-Instruct-c_abliterated-v2.Q8_0.gguf" "Qwen3-VL 4B GGUF"

print_summary
echo -e "${BLUE}Extra models installed:${NC}"
echo "  - Z-Image Turbo: Diffusion, VAE, Qwen 3 4B encoder"
echo "  - Qwen: Image Edit 2509, VL 7B"
echo "  - Ditto: Sim2Real, Global Style, Global"
echo "  - MelBandRoformer: Audio separation"
echo "  - Qwen3-VL GGUF: 8B v3, 4B v2 (abliterated)"
