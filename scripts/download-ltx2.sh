#!/bin/bash
# LTX-2 Model Download Script
# Downloads all LTX-2 related models for ComfyUI

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/download-base.sh"

# Initialize
init_paths
setup_downloader
setup_hf_auth
create_model_dirs

# Create LTX-2 LoRA directories
mkdir -p "${LORAS_DIR}/LTXV2"/{action,anime,character,clothing,concept,ltx,style}

section "LTX-2 Diffusion Models"

# Phr00t V62 merge - best quality community model (~27GB)
hf_download "Phr00t/LTX2-Rapid-Merges" "nsfw/ltx2-phr00tmerge-nsfw-v62.safetensors" "$DIFFUSION_DIR" "Phr00t V62 Merge (Primary)"

# Handle nested directory
if [ -f "${DIFFUSION_DIR}/nsfw/ltx2-phr00tmerge-nsfw-v62.safetensors" ]; then
    mv "${DIFFUSION_DIR}/nsfw/ltx2-phr00tmerge-nsfw-v62.safetensors" "${DIFFUSION_DIR}/"
    rm -rf "${DIFFUSION_DIR}/nsfw" 2>/dev/null || true
fi

# Create symlink in unet folder for compatibility
link_or_copy "${DIFFUSION_DIR}/ltx2-phr00tmerge-nsfw-v62.safetensors" "${UNET_DIR}/ltx2-phr00tmerge-nsfw-v62.safetensors"

# Official LTX-2 Dev FP8
hf_download "Lightricks/LTX-2" "ltx-2-19b-dev-fp8.safetensors" "$DIFFUSION_DIR" "LTX-2 Dev FP8 (Official)"

# Kijai's optimized variants
hf_download "Kijai/LTXV2_comfy" "diffusion_models/ltx-2-19b-dev-fp8_transformer_only.safetensors" "$DIFFUSION_DIR" "LTX-2 Dev FP8 Transformer"
hf_download "Kijai/LTXV2_comfy" "diffusion_models/ltx-2-19b-distilled-fp8_transformer_only.safetensors" "$DIFFUSION_DIR" "LTX-2 Distilled FP8 Transformer"
hf_download "Kijai/LTXV2_comfy" "diffusion_models/ltx-2-19b-dev_fp4_transformer_only.safetensors" "$DIFFUSION_DIR" "LTX-2 Dev FP4 Transformer (Fastest)"

# Move files from nested directories
if ls "${DIFFUSION_DIR}/diffusion_models/"*.safetensors 1>/dev/null 2>&1; then
    mv "${DIFFUSION_DIR}/diffusion_models/"*.safetensors "${DIFFUSION_DIR}/"
fi
rm -rf "${DIFFUSION_DIR}/diffusion_models" 2>/dev/null || true

section "LTX-2 Text Encoders"

# Gemma 3 12B variants
hf_download "Comfy-Org/ltx-2" "split_files/text_encoders/gemma_3_12B_it.safetensors" "$TEXT_ENCODER_DIR" "Gemma 3 12B (Full Precision)"
hf_download "Comfy-Org/ltx-2" "split_files/text_encoders/gemma_3_12B_it_fp8_scaled.safetensors" "$TEXT_ENCODER_DIR" "Gemma 3 12B FP8 Scaled"
hf_download "GitMylo/LTX-2-comfy_gemma_fp8_e4m3fn" "gemma_3_12B_it_fp8_e4m3fn.safetensors" "$TEXT_ENCODER_DIR" "Gemma 3 12B FP8 E4M3FN"

# Abliterated (uncensored) version
hf_download "FusionCow/Gemma-3-12b-Abliterated-LTX2" "gemma_ablit_fixed_bf16.safetensors" "$TEXT_ENCODER_DIR" "Gemma 3 12B Abliterated"

# Embeddings connectors
hf_download "Kijai/LTXV2_comfy" "text_encoders/ltx-2-19b-embeddings_connector_dev_bf16.safetensors" "$TEXT_ENCODER_DIR" "Embeddings Connector Dev"
hf_download "Kijai/LTXV2_comfy" "text_encoders/ltx-2-19b-embeddings_connector_distill_bf16.safetensors" "$TEXT_ENCODER_DIR" "Embeddings Connector Distill"

# Move files from nested directories
if ls "${TEXT_ENCODER_DIR}/split_files/text_encoders/"*.safetensors 1>/dev/null 2>&1; then
    mv "${TEXT_ENCODER_DIR}/split_files/text_encoders/"*.safetensors "${TEXT_ENCODER_DIR}/"
fi
if ls "${TEXT_ENCODER_DIR}/text_encoders/"*.safetensors 1>/dev/null 2>&1; then
    mv "${TEXT_ENCODER_DIR}/text_encoders/"*.safetensors "${TEXT_ENCODER_DIR}/"
fi
rm -rf "${TEXT_ENCODER_DIR}/split_files" "${TEXT_ENCODER_DIR}/text_encoders" 2>/dev/null || true

# Create symlinks in clip folder for compatibility
for f in "${TEXT_ENCODER_DIR}"/*.safetensors; do
    [ -f "$f" ] && link_or_copy "$f" "${CLIP_DIR}/$(basename "$f")"
done

section "LTX-2 VAEs"

hf_download "Kijai/LTXV2_comfy" "VAE/LTX2_video_vae_bf16.safetensors" "$VAE_DIR" "LTX2 Video VAE"
hf_download "Kijai/LTXV2_comfy" "VAE/LTX2_audio_vae_bf16.safetensors" "$VAE_DIR" "LTX2 Audio VAE"

# Move files from nested directories
if ls "${VAE_DIR}/VAE/"*.safetensors 1>/dev/null 2>&1; then
    mv "${VAE_DIR}/VAE/"*.safetensors "${VAE_DIR}/"
fi
rm -rf "${VAE_DIR}/VAE" 2>/dev/null || true

section "LTX-2 Official LoRAs"

# Distilled LoRA (faster inference)
hf_download "Kijai/LTXV2_comfy" "loras/ltx-2-19b-distilled-lora-resized_dynamic_fro095_avg_rank_242_bf16.safetensors" "$LORAS_DIR" "Distilled LoRA"

# Control LoRAs
hf_download "Lightricks/LTX-2-19b-IC-LoRA-Canny-Control" "ltx-2-19b-ic-lora-canny-control.safetensors" "$LORAS_DIR" "Canny Control LoRA"
hf_download "Lightricks/LTX-2-19b-IC-LoRA-Depth-Control" "ltx-2-19b-ic-lora-depth-control.safetensors" "$LORAS_DIR" "Depth Control LoRA"
hf_download "Lightricks/LTX-2-19b-IC-LoRA-Pose-Control" "ltx-2-19b-ic-lora-pose-control.safetensors" "$LORAS_DIR" "Pose Control LoRA"

# Detailer LoRA
hf_download "Lightricks/LTX-2-19b-IC-LoRA-Detailer" "ltx-2-19b-ic-lora-detailer.safetensors" "$LORAS_DIR" "Detailer LoRA"

# Camera Control
hf_download "Lightricks/LTX-2-19b-LoRA-Camera-Control-Jib-Up" "ltx-2-19b-lora-camera-control-jib-up.safetensors" "$LORAS_DIR" "Camera Jib Up LoRA"

# Move files from nested directories
if ls "${LORAS_DIR}/loras/"*.safetensors 1>/dev/null 2>&1; then
    mv "${LORAS_DIR}/loras/"*.safetensors "${LORAS_DIR}/"
fi
rm -rf "${LORAS_DIR}/loras" 2>/dev/null || true

print_summary
echo -e "${BLUE}LTX-2 models installed:${NC}"
echo "  - Diffusion: Phr00t V62, Dev FP8, Distilled FP8, FP4"
echo "  - Text Encoders: Gemma 3 12B (multiple precisions)"
echo "  - VAEs: Video VAE, Audio VAE"
echo "  - LoRAs: Distilled, Canny, Depth, Pose, Detailer, Camera"
echo ""
echo -e "${YELLOW}Upload custom LoRAs to: ${LORAS_DIR}/LTXV2/${NC}"
