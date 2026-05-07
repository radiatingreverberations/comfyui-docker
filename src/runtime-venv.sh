#!/bin/bash
set -e

VIRTUAL_ENV="${VIRTUAL_ENV:-/opt/venv}"
export VIRTUAL_ENV

RUNTIME_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

comfyui_uv_install_cached() {
    uv pip install --python "${VIRTUAL_ENV}/bin/python" "$@"
}

comfyui_install_frontend_package_copy() {
    frontend_requirement="$(grep -E '^comfyui-frontend-package==' "${RUNTIME_DIR}/requirements.lock.txt" || true)"
    if [ -z "${frontend_requirement}" ]; then
        return
    fi

    uv pip uninstall \
        --python "${VIRTUAL_ENV}/bin/python" \
        comfyui-frontend-package

    uv pip install \
        --python "${VIRTUAL_ENV}/bin/python" \
        --link-mode copy \
        --no-deps \
        "${frontend_requirement}"
}

if [ "${COMFYUI_RUNTIME_VENV_READY:-}" != "${VIRTUAL_ENV}" ]; then
    : "${OFFLOADR_TORCH_VERSION:?OFFLOADR_TORCH_VERSION must be set by the base image}"
    : "${OFFLOADR_TORCHVISION_VERSION:?OFFLOADR_TORCHVISION_VERSION must be set by the base image}"
    : "${OFFLOADR_TORCH_INDEX_URL:?OFFLOADR_TORCH_INDEX_URL must be set by the base image}"

    if [ ! -f "${VIRTUAL_ENV}/bin/activate" ]; then
        uv venv "${VIRTUAL_ENV}"
    fi

    # Symlink mode makes startup fast; the venv keeps references into /opt/uv-cache.
    comfyui_uv_install_cached \
        torch=="${OFFLOADR_TORCH_VERSION}" \
        torchvision=="${OFFLOADR_TORCHVISION_VERSION}" \
        torchaudio=="${OFFLOADR_TORCH_VERSION}" \
        --index-url "${OFFLOADR_TORCH_INDEX_URL}"

    comfyui_uv_install_cached \
        --no-deps \
        -r "${RUNTIME_DIR}/requirements.lock.txt"

    if [ -n "${OFFLOADR_WHEELHOUSE:-}" ] && [ -d "${OFFLOADR_WHEELHOUSE}" ]; then
        wheel_args=()
        while IFS= read -r -d '' wheel; do
            wheel_args+=("${wheel}")
        done < <(find "${OFFLOADR_WHEELHOUSE}" -maxdepth 1 -type f -name '*.whl' -print0 | sort -z)

        if [ "${#wheel_args[@]}" -gt 0 ]; then
            comfyui_uv_install_cached "${wheel_args[@]}"
        fi
    fi

    comfyui_install_frontend_package_copy

    export COMFYUI_RUNTIME_VENV_READY="${VIRTUAL_ENV}"
fi

# Ensure the venv executables are preferred before activation.
case ":${PATH}:" in
    *":${VIRTUAL_ENV}/bin:"*) ;;
    *) export PATH="${VIRTUAL_ENV}/bin:${PATH}" ;;
esac

source "${VIRTUAL_ENV}/bin/activate"
