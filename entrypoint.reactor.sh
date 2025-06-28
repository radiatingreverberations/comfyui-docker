#!/bin/bash
set -e

# Activate virtual environment
source venv/bin/activate

# Download the model weights (if not already present)
huggingface-cli download Gourieff/ReActor --local-dir models/reactor --repo-type dataset --include "models/detection/bbox/*.pt"
huggingface-cli download Gourieff/ReActor --local-dir models/reactor --repo-type dataset --include "models/sams/*.pth"

# Continue with original entrypoint
exec ./entrypoint.base.sh "$@"
