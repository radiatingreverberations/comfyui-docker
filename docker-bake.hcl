variable "DOCKER_REGISTRY_URL" {
    default = "ghcr.io/radiatingreverberations/"
}
variable "COMFYUI_VERSION" {
    default = "master"
}
variable "REFRESH_COMFYUI" {
    default = "0"
}
variable "CPU_BASE_IMAGE" {
    default = "ghcr.io/offloadr/base/cpu-core:py3.12-torch2.11.0-cpu"
}
variable "AMD_BASE_IMAGE" {
    default = "ghcr.io/offloadr/base/amd-core:py3.12-torch2.11.0-rocm7.2.3"
}
variable "NVIDIA_BASE_IMAGE" {
    default = "ghcr.io/offloadr/base/nvidia-full:py3.12-torch2.11.0-cuda13.0.3"
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

target "_common" {
    context    = "src"
    dockerfile = "dockerfile"
    args = {
        COMFYUI_VERSION = "${COMFYUI_VERSION}"
        REFRESH_COMFYUI = "${REFRESH_COMFYUI}"
        BASE_IMAGE      = BASE_FLAVOR == "nvidia" ? NVIDIA_BASE_IMAGE : BASE_FLAVOR == "amd" ? AMD_BASE_IMAGE : CPU_BASE_IMAGE
    }
    platforms  = ["linux/amd64"]
    cache-to   = ["type=inline"]
}

target "comfyui-base" {
    inherits   = ["_common"]
    target     = "comfyui-base"
    tags       = ["${DOCKER_REGISTRY_URL}comfyui-base:${notequal("nvidia", BASE_FLAVOR) ? "${BASE_FLAVOR}-" : ""}${IMAGE_LABEL}"]
    cache-from = ["type=registry,ref=${DOCKER_REGISTRY_URL}comfyui-base:${notequal("nvidia", BASE_FLAVOR) ? "${BASE_FLAVOR}-" : ""}${IMAGE_LABEL}"]
}

target "comfyui-extensions" {
    inherits   = ["_common"]
    target     = "comfyui-extensions"
    tags       = ["${DOCKER_REGISTRY_URL}comfyui-extensions:${notequal("nvidia", BASE_FLAVOR) ? "${BASE_FLAVOR}-" : ""}${IMAGE_LABEL}"]
    cache-from = ["type=registry,ref=${DOCKER_REGISTRY_URL}comfyui-extensions:${notequal("nvidia", BASE_FLAVOR) ? "${BASE_FLAVOR}-" : ""}${IMAGE_LABEL}"]
}

target "comfyui-ssh" {
    inherits   = ["_common"]
    target     = "comfyui-ssh"
    secret     = ["id=SSH_HOST_ED25519_KEY_B64,env=SSH_HOST_ED25519_KEY_B64"]
    tags       = ["${DOCKER_REGISTRY_URL}comfyui-ssh:${notequal("nvidia", BASE_FLAVOR) ? "${BASE_FLAVOR}-" : ""}${IMAGE_LABEL}"]
    cache-from = ["type=registry,ref=${DOCKER_REGISTRY_URL}comfyui-ssh:${notequal("nvidia", BASE_FLAVOR) ? "${BASE_FLAVOR}-" : ""}${IMAGE_LABEL}"]
}
