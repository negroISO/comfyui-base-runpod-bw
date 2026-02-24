#!/bin/bash
# Master Model Download Script
# Downloads models based on user selection

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

show_help() {
    echo -e "${CYAN}ComfyUI Model Downloader for Blackwell GPUs${NC}"
    echo ""
    echo "Usage: $0 [OPTIONS] [MODULES...]"
    echo ""
    echo "Modules:"
    echo "  ltx2      Download LTX-2 models (~80GB)"
    echo "  wan22     Download WAN 2.2 models (~100GB)"
    echo "  hunyuan   Download HunyuanVideo 1.5 models (~43GB)"
    echo "  extras    Download extra models (Ditto, Z-Image, etc.) (~30GB)"
    echo "  all       Download all models (~250GB)"
    echo ""
    echo "Options:"
    echo "  -h, --help     Show this help"
    echo "  -f, --fast     Install aria2c for faster downloads"
    echo "  -q, --quick    Quick mode - skip large models, essential only"
    echo ""
    echo "Environment Variables:"
    echo "  HF_TOKEN           HuggingFace token for authenticated downloads"
    echo "  CIVITAI_API_KEY    Civitai API key for premium models"
    echo ""
    echo "Examples:"
    echo "  $0 ltx2              # Download only LTX-2 models"
    echo "  $0 ltx2 wan22        # Download LTX-2 and WAN 2.2"
    echo "  $0 -f all            # Install aria2c and download everything"
    echo "  $0 --quick ltx2      # Download essential LTX-2 models only"
}

install_aria2() {
    if ! command -v aria2c &> /dev/null; then
        echo -e "${YELLOW}Installing aria2 for parallel downloads...${NC}"
        apt-get update -qq && apt-get install -y -qq aria2
        echo -e "${GREEN}aria2 installed!${NC}"
    else
        echo -e "${GREEN}aria2 already installed${NC}"
    fi
}

# Parse arguments
MODULES=()
INSTALL_ARIA=false
QUICK_MODE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -f|--fast)
            INSTALL_ARIA=true
            shift
            ;;
        -q|--quick)
            QUICK_MODE=true
            shift
            ;;
        ltx2|wan22|hunyuan|extras|all)
            MODULES+=("$1")
            shift
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            show_help
            exit 1
            ;;
    esac
done

# Default to showing help if no modules specified
if [ ${#MODULES[@]} -eq 0 ]; then
    show_help
    exit 0
fi

# Handle 'all' module
if [[ " ${MODULES[*]} " =~ " all " ]]; then
    MODULES=("ltx2" "wan22" "hunyuan" "extras")
fi

# Install aria2 if requested
if [ "$INSTALL_ARIA" = true ]; then
    install_aria2
fi

# Export quick mode for child scripts
export QUICK_MODE

echo ""
echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}  ComfyUI Model Downloader${NC}"
echo -e "${CYAN}  Blackwell GPU Optimized${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""
echo -e "${BLUE}Modules to download: ${MODULES[*]}${NC}"
echo ""

# Check for API keys
if [ -z "$HF_TOKEN" ]; then
    echo -e "${YELLOW}WARNING: HF_TOKEN not set - downloads may be rate-limited${NC}"
    echo -e "${YELLOW}Set with: export HF_TOKEN='your_token'${NC}"
fi
if [ -z "$CIVITAI_API_KEY" ]; then
    echo -e "${YELLOW}WARNING: CIVITAI_API_KEY not set - Civitai models will be skipped${NC}"
    echo -e "${YELLOW}Set with: export CIVITAI_API_KEY='your_key'${NC}"
fi
echo ""

# Run selected modules
for module in "${MODULES[@]}"; do
    case $module in
        ltx2)
            echo -e "${GREEN}>>> Starting LTX-2 download...${NC}"
            bash "$SCRIPT_DIR/download-ltx2.sh"
            ;;
        wan22)
            echo -e "${GREEN}>>> Starting WAN 2.2 download...${NC}"
            bash "$SCRIPT_DIR/download-wan22.sh"
            ;;
        hunyuan)
            echo -e "${GREEN}>>> Starting HunyuanVideo 1.5 download...${NC}"
            bash "$SCRIPT_DIR/download-hunyuan.sh"
            ;;
        extras)
            echo -e "${GREEN}>>> Starting extras download...${NC}"
            bash "$SCRIPT_DIR/download-extras.sh"
            ;;
    esac
done

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  ALL DOWNLOADS COMPLETE${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Restart ComfyUI to load new models"
echo "  2. Upload custom LoRAs via FileBrowser (port 8080)"
echo "  3. Load a workflow and start generating!"
