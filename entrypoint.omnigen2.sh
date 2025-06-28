#!/bin/bash
set -e

# Activate virtual environment
source venv/bin/activate

# Download the model weights (if not already present)
huggingface-cli download OmniGen2/OmniGen2 --local-dir models/omnigen2

# Continue with original entrypoint
exec ./entrypoint.base.sh "$@"
