# variables pulled from .env or CLI
variable "DOCKER_REGISTRY_URL" {
    default = ""
}
variable "NVIDIA_BASE_IMAGE" {
    default = "12.8.1-devel-ubuntu24.04"
}
variable "COMFYUI_REF" {
    default = "heads/master"
}

group "default" {
    targets = ["comfyui-base", "comfyui-extensions", "comfyui-reactor"]
}

target "comfyui-base" {
    context    = "."
    dockerfile = "dockerfile.base"
    args = {
        NVIDIA_BASE_IMAGE = "${NVIDIA_BASE_IMAGE}"
        COMFYUI_REF       = "${COMFYUI_REF}"
    }
    tags       = ["${DOCKER_REGISTRY_URL}comfyui-base:latest"]
    platforms  = ["linux/amd64"]
    cache-from = ["type=registry,ref=${DOCKER_REGISTRY_URL}comfyui-base:latest"]
    cache-to   = ["type=inline"]
}

target "comfyui-extensions" {
    context    = "."
    dockerfile = "dockerfile.extensions"
    contexts = {
        comfyui-base = "target:comfyui-base"
    }
    tags       = ["${DOCKER_REGISTRY_URL}comfyui-extensions:latest"]
    platforms  = ["linux/amd64"]
    cache-from = ["type=registry,ref=${DOCKER_REGISTRY_URL}comfyui-extensions:latest"]
    cache-to   = ["type=inline"]
}

target "comfyui-omnigen2" {
    context    = "."
    dockerfile = "dockerfile.omnigen2"
    contexts = {
        comfyui-extensions = "target:comfyui-extensions"
    }
    tags       = ["${DOCKER_REGISTRY_URL}comfyui-omnigen2:latest"]
    platforms  = ["linux/amd64"]
    cache-from = ["type=registry,ref=${DOCKER_REGISTRY_URL}comfyui-omnigen2:latest"]
    cache-to   = ["type=inline"]
}

target "comfyui-reactor" {
    context    = "."
    dockerfile = "dockerfile.reactor"
    contexts = {
        comfyui-extensions = "target:comfyui-extensions"
    }
    tags       = ["${DOCKER_REGISTRY_URL}comfyui-reactor:latest"]
    platforms  = ["linux/amd64"]
    cache-from = ["type=registry,ref=${DOCKER_REGISTRY_URL}comfyui-reactor:latest"]
    cache-to   = ["type=inline"]
}