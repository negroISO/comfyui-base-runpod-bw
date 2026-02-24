#!/bin/bash
# WAN 2.2 Model Download Script
# Downloads all WAN 2.1/2.2 models for ComfyUI (I2V, T2V, SVI)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/download-base.sh"

# Initialize
init_paths
setup_downloader
setup_hf_auth
create_model_dirs

# Create WAN LoRA directories
mkdir -p "${LORAS_DIR}/wan2.2"
mkdir -p "${LORAS_DIR}/Wan Video 2.2 I2V-A14B"/{action,concept,poses,style}
mkdir -p "${LORAS_DIR}/Wan Video 2.2 T2V-A14B"/{character,concept,style}

section "WAN 2.2 I2V Diffusion Models"

# Comfy-Org official I2V models
hf_download "Comfy-Org/Wan_2.2_ComfyUI_Repackaged" "split_files/diffusion_models/wan2.2_i2v_high_noise_14B_fp8_scaled.safetensors" "$DIFFUSION_DIR" "WAN 2.2 I2V High Noise"
hf_download "Comfy-Org/Wan_2.2_ComfyUI_Repackaged" "split_files/diffusion_models/wan2.2_i2v_low_noise_14B_fp8_scaled.safetensors" "$DIFFUSION_DIR" "WAN 2.2 I2V Low Noise"

# Kijai's FP8 scaled versions
hf_download "Kijai/WanVideo_comfy_fp8_scaled" "I2V/Wan2_2-I2V-A14B-LOW_fp8_e4m3fn_scaled_KJ.safetensors" "$DIFFUSION_DIR" "WAN 2.2 I2V LOW (Kijai)"
hf_download "Kijai/WanVideo_comfy_fp8_scaled" "I2V/Wan2_2-I2V-A14B-HIGH_fp8_e4m3fn_scaled_KJ.safetensors" "$DIFFUSION_DIR" "WAN 2.2 I2V HIGH (Kijai)"

# Move nested files
for subdir in "split_files/diffusion_models" "I2V"; do
    if ls "${DIFFUSION_DIR}/${subdir}/"*.safetensors 1>/dev/null 2>&1; then
        mv "${DIFFUSION_DIR}/${subdir}/"*.safetensors "${DIFFUSION_DIR}/"
    fi
done
rm -rf "${DIFFUSION_DIR}/split_files" "${DIFFUSION_DIR}/I2V" 2>/dev/null || true

section "WAN 2.2 T2V Diffusion Models"

hf_download "Comfy-Org/Wan_2.2_ComfyUI_Repackaged" "split_files/diffusion_models/wan2.2_t2v_high_noise_14B_fp8_scaled.safetensors" "$DIFFUSION_DIR" "WAN 2.2 T2V High Noise"
hf_download "Comfy-Org/Wan_2.2_ComfyUI_Repackaged" "split_files/diffusion_models/wan2.2_t2v_low_noise_14B_fp8_scaled.safetensors" "$DIFFUSION_DIR" "WAN 2.2 T2V Low Noise"

# WAN 2.1 T2V (for CausVid LoRA)
hf_download "Kijai/WanVideo_comfy" "Wan2_1-T2V-14B_fp8_e4m3fn.safetensors" "$DIFFUSION_DIR" "WAN 2.1 T2V 14B"

# Move nested files
if ls "${DIFFUSION_DIR}/split_files/diffusion_models/"*.safetensors 1>/dev/null 2>&1; then
    mv "${DIFFUSION_DIR}/split_files/diffusion_models/"*.safetensors "${DIFFUSION_DIR}/"
fi
rm -rf "${DIFFUSION_DIR}/split_files" 2>/dev/null || true

section "WAN 2.2 Text Encoders"

hf_download "Comfy-Org/Wan_2.1_ComfyUI_repackaged" "split_files/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors" "$TEXT_ENCODER_DIR" "UMT5 XXL FP8"
hf_download "Kijai/WanVideo_comfy" "umt5-xxl-enc-bf16.safetensors" "$TEXT_ENCODER_DIR" "UMT5 XXL BF16"

# NSFW UMT5 (uncensored)
hf_download "NSFW-API/NSFW-Wan-UMT5-XXL" "nsfw_wan_umt5-xxl_fp8_scaled.safetensors" "$TEXT_ENCODER_DIR" "NSFW UMT5 XXL FP8"
hf_download "NSFW-API/NSFW-Wan-UMT5-XXL" "nsfw_wan_umt5-xxl_bf16.safetensors" "$TEXT_ENCODER_DIR" "NSFW UMT5 XXL BF16"

# Move nested files
if ls "${TEXT_ENCODER_DIR}/split_files/text_encoders/"*.safetensors 1>/dev/null 2>&1; then
    mv "${TEXT_ENCODER_DIR}/split_files/text_encoders/"*.safetensors "${TEXT_ENCODER_DIR}/"
fi
rm -rf "${TEXT_ENCODER_DIR}/split_files" 2>/dev/null || true

section "WAN 2.2 VAE"

hf_download "Comfy-Org/Wan_2.2_ComfyUI_Repackaged" "split_files/vae/wan_2.1_vae.safetensors" "$VAE_DIR" "WAN 2.1 VAE"
hf_download "Kijai/WanVideo_comfy" "Wan2_1_VAE_bf16.safetensors" "$VAE_DIR" "WAN 2.1 VAE BF16"

# Move nested files
if ls "${VAE_DIR}/split_files/vae/"*.safetensors 1>/dev/null 2>&1; then
    mv "${VAE_DIR}/split_files/vae/"*.safetensors "${VAE_DIR}/"
fi
rm -rf "${VAE_DIR}/split_files" 2>/dev/null || true

section "WAN 2.2 SVI & Distill LoRAs"

# SVI v2 PRO LoRAs
hf_download "Kijai/WanVideo_comfy" "LoRAs/Stable-Video-Infinity/v2.0/SVI_v2_PRO_Wan2.2-I2V-A14B_HIGH_lora_rank_128_fp16.safetensors" "$LORAS_DIR" "SVI v2 PRO HIGH"
hf_download "Kijai/WanVideo_comfy" "LoRAs/Stable-Video-Infinity/v2.0/SVI_v2_PRO_Wan2.2-I2V-A14B_LOW_lora_rank_128_fp16.safetensors" "$LORAS_DIR" "SVI v2 PRO LOW"

# Lightning LoRAs (4-step)
hf_download "Kijai/WanVideo_comfy" "LoRAs/Wan22-Lightning/old/Wan2.2-Lightning_I2V-A14B-4steps-lora_HIGH_fp16.safetensors" "$LORAS_DIR" "Lightning HIGH"
hf_download "Kijai/WanVideo_comfy" "LoRAs/Wan22-Lightning/old/Wan2.2-Lightning_I2V-A14B-4steps-lora_LOW_fp16.safetensors" "$LORAS_DIR" "Lightning LOW"

# LightX2V 4-Steps LoRAs
hf_download "Comfy-Org/Wan_2.2_ComfyUI_Repackaged" "split_files/loras/wan2.2_i2v_lightx2v_4steps_lora_v1_high_noise.safetensors" "$LORAS_DIR" "LightX2V 4-Steps HIGH"
hf_download "Comfy-Org/Wan_2.2_ComfyUI_Repackaged" "split_files/loras/wan2.2_i2v_lightx2v_4steps_lora_v1_low_noise.safetensors" "$LORAS_DIR" "LightX2V 4-Steps LOW"

# LightX2V Step Distill LoRAs
hf_download "lightx2v/Wan2.1-I2V-14B-480P-StepDistill-CfgDistill-Lightx2v" "loras/Wan21_I2V_14B_lightx2v_cfg_step_distill_lora_rank64.safetensors" "$LORAS_DIR" "LightX2V Step Distill"
hf_download "Kijai/WanVideo_comfy" "Lightx2v/lightx2v_I2V_14B_480p_cfg_step_distill_rank128_bf16.safetensors" "$LORAS_DIR" "LightX2V I2V 480p"

# CausVid T2V LoRA v2
hf_download "Kijai/WanVideo_comfy" "Wan21_CausVid_14B_T2V_lora_rank32_v2.safetensors" "$LORAS_DIR" "CausVid T2V LoRA v2"

# Move nested files
for subdir in "LoRAs" "split_files/loras" "loras" "Lightx2v"; do
    find "${LORAS_DIR}/${subdir}" -name "*.safetensors" -exec mv {} "${LORAS_DIR}/" \; 2>/dev/null || true
done
rm -rf "${LORAS_DIR}/LoRAs" "${LORAS_DIR}/split_files" "${LORAS_DIR}/loras" "${LORAS_DIR}/Lightx2v" 2>/dev/null || true

section "WAN 2.2 Civitai Models (requires CIVITAI_API_KEY)"

# SVI Consistent Face models
civitai_download "2609141" "${DIFFUSION_DIR}/Wan2_2-I2V-A14B-HIGH_SVI_consistent_face_nsfw_fp8.safetensors" "SVI cf HIGH"
civitai_download "2609148" "${DIFFUSION_DIR}/Wan2_2-I2V-A14B-LOW_SVI_consistent_face_nsfw_fp8.safetensors" "SVI cf LOW"

# DaSiWa models
civitai_download "2555640" "${DIFFUSION_DIR}/Wan2_2-I2V-High-DaSiWa-SynthSeduction-v9-fp8.safetensors" "DaSiWa HIGH"
civitai_download "2555652" "${DIFFUSION_DIR}/Wan2_2-I2V-Low-DaSiWa-SynthSeduction-v9-fp8.safetensors" "DaSiWa LOW"

# French Kiss models
civitai_download "2445168" "${DIFFUSION_DIR}/WAN2.2-FrenchKiss_HighNoise.safetensors" "French Kiss HIGH"
civitai_download "2445176" "${DIFFUSION_DIR}/WAN2.2-FrenchKiss_LowNoise.safetensors" "French Kiss LOW"

# Remix NSFW models
hf_download "FX-FeiHou/wan2.2-Remix" "NSFW/Wan2.2_Remix_NSFW_i2v_14b_high_lighting_fp8_e4m3fn_v2.1.safetensors" "$DIFFUSION_DIR" "Remix NSFW HIGH"
hf_download "FX-FeiHou/wan2.2-Remix" "NSFW/Wan2.2_Remix_NSFW_i2v_14b_low_lighting_fp8_e4m3fn_v2.1.safetensors" "$DIFFUSION_DIR" "Remix NSFW LOW"

# Move NSFW folder files
if ls "${DIFFUSION_DIR}/NSFW/"*.safetensors 1>/dev/null 2>&1; then
    mv "${DIFFUSION_DIR}/NSFW/"*.safetensors "${DIFFUSION_DIR}/"
fi
rm -rf "${DIFFUSION_DIR}/NSFW" 2>/dev/null || true

section "GGUF Models (for VRAM efficiency)"

mkdir -p "${UNET_DIR}"
civitai_download "2584698" "${UNET_DIR}/wan22EnhancedNSFWSVICamera_nsfwV2Q8High.gguf" "SVI Camera GGUF HIGH"
civitai_download "2584707" "${UNET_DIR}/wan22EnhancedNSFWSVICamera_nsfwV2Q8Low.gguf" "SVI Camera GGUF LOW"

section "Utility Models (RIFE, Upscalers)"

mkdir -p "${MODELS_DIR}/rife"

# RIFE interpolation
hf_download "hfmaster/models-moved" "rife/rife49.pth" "${MODELS_DIR}/rife" "RIFE 4.9"
if [ -f "${MODELS_DIR}/rife/rife/rife49.pth" ]; then
    mv "${MODELS_DIR}/rife/rife/rife49.pth" "${MODELS_DIR}/rife/"
    rm -rf "${MODELS_DIR}/rife/rife" 2>/dev/null || true
fi

# Upscaler
if [ ! -f "${UPSCALE_DIR}/2xLexicaRRDBNet.safetensors" ]; then
    download_file "https://huggingface.co/Phhofm/2xLexicaRRDBNet/resolve/main/2xLexicaRRDBNet.safetensors" \
        "${UPSCALE_DIR}/2xLexicaRRDBNet.safetensors" "2xLexicaRRDBNet"
fi

print_summary
echo -e "${BLUE}WAN 2.2 models installed:${NC}"
echo "  - I2V: High/Low noise (Comfy-Org + Kijai)"
echo "  - T2V: High/Low noise"
echo "  - SVI: v2 PRO, Lightning, LightX2V, CausVid"
echo "  - NSFW: SVI cf, DaSiWa, French Kiss, Remix"
echo "  - Utils: RIFE 4.9, 2xLexicaRRDBNet"
echo ""
echo -e "${YELLOW}Upload custom LoRAs to: ${LORAS_DIR}/Wan Video 2.2 I2V-A14B/${NC}"
