#!/bin/bash
# Quick script to restart ComfyUI

COMFYUI_DIR="/workspace/runpod-slim/ComfyUI"
VENV_DIR="$COMFYUI_DIR/.venv"
ARGS_FILE="/workspace/runpod-slim/comfyui_args.txt"

echo "Stopping ComfyUI..."
pkill -f 'python.*main.py' 2>/dev/null || true
sleep 2

echo "Starting ComfyUI..."
cd $COMFYUI_DIR
source $VENV_DIR/bin/activate

FIXED_ARGS="--listen 0.0.0.0 --port 8188"
CUSTOM_ARGS=""

if [ -s "$ARGS_FILE" ]; then
    CUSTOM_ARGS=$(grep -v '^#' "$ARGS_FILE" | grep -v '^$' | tr '\n' ' ')
fi

nohup python main.py $FIXED_ARGS $CUSTOM_ARGS &> /workspace/runpod-slim/comfyui.log &

echo "ComfyUI restarted!"
echo "Logs: tail -f /workspace/runpod-slim/comfyui.log"
