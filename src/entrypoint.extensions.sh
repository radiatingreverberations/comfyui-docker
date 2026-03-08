#!/bin/bash
set -e

ensure_symlink() {
	local target="$1"
	local link_path="$2"
	local link_dir

	link_dir=$(dirname "$link_path")
	mkdir -p "$link_dir"

	if [ -L "$link_path" ]; then
		if [ "$(readlink "$link_path")" = "$target" ]; then
			return
		fi
		rm "$link_path"
	elif [ -e "$link_path" ]; then
		echo "Refusing to replace non-symlink path: $link_path" >&2
		exit 1
	fi

	ln -s "$target" "$link_path"
}

# Make the built-in ComfyUI-Manager available in the custom_nodes directory
ensure_symlink /comfyui-manager /comfyui/custom_nodes/ComfyUI-Manager

# Ensure that the ComfyUI-Manager cache is available on first run
ensure_symlink /comfyui-manager-cache /comfyui/user/__manager/cache

# Activate virtual environment
source venv/bin/activate

# Ensure ComfyUI-Manager config exists and has use_uv = True
python - <<'PYCFG'
import configparser, pathlib
cfg_path = pathlib.Path('/comfyui/user/__manager/config.ini')
cfg_path.parent.mkdir(parents=True, exist_ok=True)
if not cfg_path.exists():
	# Minimal file with required settings
	cfg_path.write_text('[default]\nuse_uv = True\nnetwork_mode = offline\n')
else:
	cfg = configparser.ConfigParser()
	cfg.read(cfg_path)
	if 'default' not in cfg:
		cfg['default'] = {}
	cfg['default']['use_uv'] = 'True'
	with cfg_path.open('w') as f:
		cfg.write(f)
PYCFG

# Python dependencies for custom nodes need reinstallation after updates
python /comfyui-manager/cm-cli.py fix all

# Continue with original entrypoint
exec ./entrypoint.base.sh "$@"
