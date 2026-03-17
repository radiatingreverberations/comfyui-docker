#!/bin/bash
set -e

# Activate virtual environment
source venv/bin/activate

# Ensure ComfyUI-Manager config exists and has use_uv = True
python - <<'PYCFG'
import configparser, pathlib
cfg_path = pathlib.Path('/comfyui/user/__manager/config.ini')
cfg_path.parent.mkdir(parents=True, exist_ok=True)
if not cfg_path.exists():
	# Minimal file with required settings
	cfg_path.write_text('[default]\nuse_uv = True\nnetwork_mode = personal_cloud\n')
else:
	cfg = configparser.ConfigParser()
	cfg.read(cfg_path)
	if 'default' not in cfg:
		cfg['default'] = {}
	cfg['default']['use_uv'] = 'True'
	with cfg_path.open('w') as f:
		cfg.write(f)
PYCFG

# Continue with original entrypoint
exec ./entrypoint.base.sh --enable-manager "$@"
