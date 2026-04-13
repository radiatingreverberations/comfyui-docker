variable "DOCKER_REGISTRY_URL" {
    default = "ghcr.io/radiatingreverberations/"
}
variable "COMFYUI_VERSION" {
    default = "master"
}
variable "CPU_BASE_IMAGE" {
    default = "ghcr.io/offloadr/base/cpu-core:py3.12-torch2.10.0-cpu"
}
variable "AMD_BASE_IMAGE" {
    default = "ghcr.io/offloadr/base/amd-core:py3.12-torch2.10.0-rocm7.1"
}
variable "NVIDIA_BASE_IMAGE" {
    default = "ghcr.io/offloadr/base/nvidia-full:py3.12-torch2.10.0-cuda13.0.2"
}
variable "IMAGE_LABEL" {
    default = "latest"
    validation {
        condition     = IMAGE_LABEL == "latest" || IMAGE_LABEL == "master"
        error_message = "The variable 'IMAGE_LABEL' must be 'latest' or 'master'."
  }
}
variable "BASE_FLAVOR" {
    default = "cpu"
    validation {
        condition     = BASE_FLAVOR == "nvidia" || BASE_FLAVOR == "cpu" || BASE_FLAVOR == "amd"
        error_message = "The variable 'BASE_FLAVOR' must be 'nvidia' or 'cpu' or 'amd'."
    }
}

group "default" {
    targets = [
        "comfyui-base",
        "comfyui-extensions",
        "comfyui-ssh"
    ]
}

target "comfyui-base" {
    context    = "src"
    dockerfile = "dockerfile.base"
    args = {
        COMFYUI_VERSION = "${COMFYUI_VERSION}"
        BASE_IMAGE      = BASE_FLAVOR == "nvidia" ? NVIDIA_BASE_IMAGE : BASE_FLAVOR == "amd" ? AMD_BASE_IMAGE : CPU_BASE_IMAGE
    }
    tags       = ["${DOCKER_REGISTRY_URL}comfyui-base:${notequal("nvidia", BASE_FLAVOR) ? "${BASE_FLAVOR}-" : ""}${IMAGE_LABEL}"]
    platforms  = ["linux/amd64"]
    cache-from = ["type=registry,ref=${DOCKER_REGISTRY_URL}comfyui-base:${notequal("nvidia", BASE_FLAVOR) ? "${BASE_FLAVOR}-" : ""}${IMAGE_LABEL}"]
    cache-to   = ["type=inline"]
}

target "comfyui-extensions" {
    context    = "src"
    dockerfile = "dockerfile.extensions"
    contexts = {
        comfyui-base = "target:comfyui-base"
    }
    args = {
        COMFYUI_BASE_IMAGE = "comfyui-base"
    }
    tags       = ["${DOCKER_REGISTRY_URL}comfyui-extensions:${notequal("nvidia", BASE_FLAVOR) ? "${BASE_FLAVOR}-" : ""}${IMAGE_LABEL}"]
    platforms  = ["linux/amd64"]
    cache-from = ["type=registry,ref=${DOCKER_REGISTRY_URL}comfyui-extensions:${notequal("nvidia", BASE_FLAVOR) ? "${BASE_FLAVOR}-" : ""}${IMAGE_LABEL}"]
    cache-to   = ["type=inline"]
}

target "comfyui-ssh" {
    context    = "src"
    dockerfile = "dockerfile.ssh"
    contexts = {
        comfyui-extensions = "target:comfyui-extensions"
    }
    args = {
        COMFYUI_EXTENSIONS_IMAGE = "comfyui-extensions"
    }
    secret     = ["id=SSH_HOST_ED25519_KEY_B64,env=SSH_HOST_ED25519_KEY_B64"]
    tags       = ["${DOCKER_REGISTRY_URL}comfyui-ssh:${notequal("nvidia", BASE_FLAVOR) ? "${BASE_FLAVOR}-" : ""}${IMAGE_LABEL}"]
    platforms  = ["linux/amd64"]
    cache-from = ["type=registry,ref=${DOCKER_REGISTRY_URL}comfyui-ssh:${notequal("nvidia", BASE_FLAVOR) ? "${BASE_FLAVOR}-" : ""}${IMAGE_LABEL}"]
    cache-to   = ["type=inline"]
}
