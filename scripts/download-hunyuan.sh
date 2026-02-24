#!/bin/bash
# HunyuanVideo 1.5 Model Download Script
# Downloads all HunyuanVideo 1.5 models for ComfyUI

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/download-base.sh"

# Initialize
init_paths
setup_downloader
setup_hf_auth
create_model_dirs

# Create additional directories
LATENT_UPSCALE_DIR="${MODELS_DIR}/latent_upscale_models"
mkdir -p "$LATENT_UPSCALE_DIR" "$CLIP_VISION_DIR"

section "HunyuanVideo 1.5 Diffusion Models (~31GB)"

# 720p I2V model
hf_download "Comfy-Org/HunyuanVideo_1.5_repackaged" "split_files/diffusion_models/hunyuanvideo1.5_720p_i2v_fp16.safetensors" "$DIFFUSION_DIR" "HunyuanVideo 1.5 720p I2V"

# 1080p SR Distilled model
hf_download "Comfy-Org/HunyuanVideo_1.5_repackaged" "split_files/diffusion_models/hunyuanvideo1.5_1080p_sr_distilled_fp16.safetensors" "$DIFFUSION_DIR" "HunyuanVideo 1.5 1080p SR"

# Move nested files
find "${DIFFUSION_DIR}/split_files" -name "*.safetensors" -exec mv {} "${DIFFUSION_DIR}/" \; 2>/dev/null || true
rm -rf "${DIFFUSION_DIR}/split_files" 2>/dev/null || true

section "HunyuanVideo 1.5 VAE"

hf_download "Comfy-Org/HunyuanVideo_1.5_repackaged" "split_files/vae/hunyuanvideo15_vae_fp16.safetensors" "$VAE_DIR" "HunyuanVideo 1.5 VAE"

# Move nested files
find "${VAE_DIR}/split_files" -name "*.safetensors" -exec mv {} "${VAE_DIR}/" \; 2>/dev/null || true
rm -rf "${VAE_DIR}/split_files" 2>/dev/null || true

section "HunyuanVideo 1.5 Latent Upsampler"

hf_download "Comfy-Org/HunyuanVideo_1.5_repackaged" "split_files/latent_upscale_models/hunyuanvideo15_latent_upsampler_1080p.safetensors" "$LATENT_UPSCALE_DIR" "Latent Upsampler 1080p"

# Move nested files
find "${LATENT_UPSCALE_DIR}/split_files" -name "*.safetensors" -exec mv {} "${LATENT_UPSCALE_DIR}/" \; 2>/dev/null || true
rm -rf "${LATENT_UPSCALE_DIR}/split_files" 2>/dev/null || true

section "HunyuanVideo 1.5 Text Encoders"

hf_download "Comfy-Org/HunyuanVideo_1.5_repackaged" "split_files/text_encoders/byt5_small_glyphxl_fp16.safetensors" "$TEXT_ENCODER_DIR" "ByT5 Small GlyphXL"
hf_download "Comfy-Org/HunyuanVideo_1.5_repackaged" "split_files/text_encoders/qwen_2.5_vl_7b_fp8_scaled.safetensors" "$TEXT_ENCODER_DIR" "Qwen 2.5 VL 7B FP8"

# Move nested files
find "${TEXT_ENCODER_DIR}/split_files" -name "*.safetensors" -exec mv {} "${TEXT_ENCODER_DIR}/" \; 2>/dev/null || true
rm -rf "${TEXT_ENCODER_DIR}/split_files" 2>/dev/null || true

section "CLIP Vision Encoder"

hf_download "Comfy-Org/sigclip_vision_384" "sigclip_vision_patch14_384.safetensors" "$CLIP_VISION_DIR" "SigCLIP Vision 384"

print_summary
echo -e "${BLUE}HunyuanVideo 1.5 models installed:${NC}"
echo "  - Diffusion: 720p I2V (~15.5GB), 1080p SR (~15.5GB)"
echo "  - VAE: hunyuanvideo15_vae_fp16 (~2.4GB)"
echo "  - Latent Upsampler: 1080p"
echo "  - Text Encoders: ByT5 GlyphXL, Qwen 2.5 VL 7B FP8 (~8.7GB)"
echo "  - Vision: SigCLIP 384"
