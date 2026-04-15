#!/bin/bash
set -e

VIRTUAL_ENV="${VIRTUAL_ENV:-/opt/venv}"
export VIRTUAL_ENV

if [ ! -f "${VIRTUAL_ENV}/bin/activate" ]; then
    uv venv "${VIRTUAL_ENV}" --system-site-packages
fi

# Ensure the venv executables are preferred before activation.
case ":${PATH}:" in
    *":${VIRTUAL_ENV}/bin:"*) ;;
    *) export PATH="${VIRTUAL_ENV}/bin:${PATH}" ;;
esac

source "${VIRTUAL_ENV}/bin/activate"
