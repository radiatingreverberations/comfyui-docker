#!/bin/bash
set -e

# Make the built-in ComfyUI-Manager available in the custom_nodes directory
ln -s /comfyui-manager /comfyui/custom_nodes/ComfyUI-Manager

# Activate virtual environment
source venv/bin/activate

# Python dependencies for custom nodes need reinstallation after updates
python /comfyui-manager/cm-cli.py fix all

# Continue with original entrypoint
exec ./entrypoint.base.sh "$@"
