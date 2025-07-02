# variables pulled from .env or CLI
variable "DOCKER_REGISTRY_URL" {
    default = ""
}
variable "COMFYUI_VERSION" {
    default = "refs/heads/master"
}
variable "IMAGE_LABEL" {
    default = "latest"
}

group "default" {
    targets = [
        "comfyui-base",
        "comfyui-extensions",
        "comfyui-reactor"
    ]
}

target "nvidia-base" {
    context = "."
    dockerfile = "dockerfile.nvidia"
    platforms = [ "linux/amd64" ]
    tags       = ["${DOCKER_REGISTRY_URL}comfyui-base:nvidia"]
    cache-from = ["type=registry,ref=${DOCKER_REGISTRY_URL}comfyui-base:nvidia"]
    cache-to   = ["type=inline"]
}

target "comfyui-base" {
    context    = "."
    dockerfile = "dockerfile.base"
    contexts = {
        base = "target:nvidia-base"
    }
    args = {
        COMFYUI_VERSION = "${COMFYUI_VERSION}"
    }
    tags       = ["${DOCKER_REGISTRY_URL}comfyui-base:${IMAGE_LABEL}"]
    platforms  = ["linux/amd64"]
    cache-from = ["type=registry,ref=${DOCKER_REGISTRY_URL}comfyui-base:${IMAGE_LABEL}"]
    cache-to   = ["type=inline"]
}

target "comfyui-extensions" {
    context    = "."
    dockerfile = "dockerfile.extensions"
    contexts = {
        comfyui-base = "target:comfyui-base"
    }
    tags       = ["${DOCKER_REGISTRY_URL}comfyui-extensions:${IMAGE_LABEL}"]
    platforms  = ["linux/amd64"]
    cache-from = ["type=registry,ref=${DOCKER_REGISTRY_URL}comfyui-extensions:${IMAGE_LABEL}"]
    cache-to   = ["type=inline"]
}

target "comfyui-omnigen2" {
    context    = "."
    dockerfile = "dockerfile.omnigen2"
    contexts = {
        comfyui-extensions = "target:comfyui-extensions"
    }
    tags       = ["${DOCKER_REGISTRY_URL}comfyui-omnigen2:${IMAGE_LABEL}"]
    platforms  = ["linux/amd64"]
    cache-from = ["type=registry,ref=${DOCKER_REGISTRY_URL}comfyui-omnigen2:${IMAGE_LABEL}"]
    cache-to   = ["type=inline"]
}

target "comfyui-reactor" {
    context    = "."
    dockerfile = "dockerfile.reactor"
    contexts = {
        comfyui-extensions = "target:comfyui-extensions"
    }
    tags       = ["${DOCKER_REGISTRY_URL}comfyui-reactor:${IMAGE_LABEL}"]
    platforms  = ["linux/amd64"]
    cache-from = ["type=registry,ref=${DOCKER_REGISTRY_URL}comfyui-reactor:${IMAGE_LABEL}"]
    cache-to   = ["type=inline"]
}