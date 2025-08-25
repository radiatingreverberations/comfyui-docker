#!/bin/bash
set -e

# Make the built-in ComfyUI-Manager available in the custom_nodes directory
ln -s /comfyui-manager /comfyui/custom_nodes/ComfyUI-Manager

# Ensure that the ComfyUI-Manager cache is available on first run
ln -s /comfyui-manager-cache /comfyui/user/default/ComfyUI-Manager/cache

# Activate virtual environment
source venv/bin/activate

# Ensure ComfyUI-Manager config exists and has use_uv = True
python - <<'PYCFG'
import configparser, pathlib
cfg_path = pathlib.Path('/comfyui/user/default/ComfyUI-Manager/config.ini')
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
	cfg['default']['network_mode'] = 'offline'
	with cfg_path.open('w') as f:
		cfg.write(f)
PYCFG

# Python dependencies for custom nodes need reinstallation after updates
python /comfyui-manager/cm-cli.py fix all

# Continue with original entrypoint
exec ./entrypoint.base.sh "$@"
