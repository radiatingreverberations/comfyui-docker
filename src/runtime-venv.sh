#!/bin/bash
set -e

VIRTUAL_ENV="${OFFLOADR_VENV:-/opt/venv}"
export VIRTUAL_ENV

if [ ! -f "${VIRTUAL_ENV}/bin/activate" ]; then
    echo "Expected baked virtual environment at ${VIRTUAL_ENV}, but it was not found." >&2
    exit 1
fi

# Ensure the venv executables are preferred before activation.
case ":${PATH}:" in
    *":${VIRTUAL_ENV}/bin:"*) ;;
    *) export PATH="${VIRTUAL_ENV}/bin:${PATH}" ;;
esac

source "${VIRTUAL_ENV}/bin/activate"
