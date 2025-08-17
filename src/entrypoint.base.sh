#!/bin/bash
set -e

# Activate virtual environment
source venv/bin/activate

# Inject mandatory --cpu flag for CPU-only images unless already present
if [ -n "${COMFY_FORCE_CPU:-}" ]; then
	have_flag=0
	for a in "$@"; do
		case "$a" in
			--cpu*) have_flag=1; break ;;
		esac
	done
	if [ $have_flag -eq 0 ]; then
		set -- --cpu "$@"
	fi
fi

# Start ComfyUI with the specified parameters
exec python main.py --listen "$@"