#!/bin/bash
set -e

# Activate virtual environment
source venv/bin/activate

# Start ComfyUI with the specified parameters
python main.py --listen --preview-method auto --use-sage-attention "$@"