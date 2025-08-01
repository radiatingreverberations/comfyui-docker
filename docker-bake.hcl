variable "DOCKER_REGISTRY_URL" {
    default = ""
}
variable "COMFYUI_VERSION" {
    default = "master"
}
variable "IMAGE_LABEL" {
    default = "latest"
    validation {
        condition     = IMAGE_LABEL == "latest" || IMAGE_LABEL == "master"
        error_message = "The variable 'IMAGE_LABEL' must be 'latest' or 'master'."
  }
}
variable "BASE_FLAVOR" {
    default = "nvidia"
    validation {
        condition     = BASE_FLAVOR == "nvidia" || BASE_FLAVOR == "cpu" || BASE_FLAVOR == "amd"
        error_message = "The variable 'BASE_FLAVOR' must be 'nvidia' or 'cpu' or 'amd'."
    }
}

group "nvidia-base" {
    targets = [
        "nvidia-builder",
        "nvidia-base",
    ]
}

group "cpu-base" {
    targets = [
        "cpu-base",
    ]
}

group "amd-base" {
    targets = [
        "amd-base",
    ]
}

group "base" {
    targets = [
        "${BASE_FLAVOR}-base",
    ]
}

group "default" {
    targets = [
        "comfyui-base",
        "comfyui-extensions",
        "comfyui-reactor"
    ]
}

target "nvidia-builder" {
    context = "."
    dockerfile = "dockerfile.nvidia.builder"
    platforms = [ "linux/amd64" ]
    tags       = ["${DOCKER_REGISTRY_URL}nvidia-builder:latest"]
    cache-from = ["type=registry,ref=${DOCKER_REGISTRY_URL}nvidia-builder:latest"]
    cache-to   = ["type=inline"]
}

target "nvidia-base" {
    context = "."
    dockerfile = "dockerfile.nvidia.base"
    contexts = {
        builder = "target:nvidia-builder"
    }
    platforms = [ "linux/amd64" ]
    tags       = ["${DOCKER_REGISTRY_URL}comfyui-base:nvidia"]
    cache-from = ["type=registry,ref=${DOCKER_REGISTRY_URL}comfyui-base:nvidia"]
    cache-to   = ["type=inline"]
}

target "cpu-base" {
    context = "."
    dockerfile = "dockerfile.cpu.base"
    platforms = [ "linux/amd64" ]
    tags       = ["${DOCKER_REGISTRY_URL}comfyui-base:cpu"]
    cache-from = ["type=registry,ref=${DOCKER_REGISTRY_URL}comfyui-base:cpu"]
    cache-to   = ["type=inline"]
}

target "amd-base" {
    context = "."
    dockerfile = "dockerfile.amd.base"
    platforms = [ "linux/amd64" ]
    tags       = ["${DOCKER_REGISTRY_URL}comfyui-base:amd"]
    cache-from = ["type=registry,ref=${DOCKER_REGISTRY_URL}comfyui-base:amd"]
    cache-to   = ["type=inline"]
}

target "comfyui-base" {
    context    = "."
    dockerfile = "dockerfile.base"
    contexts = {
        base = "target:${BASE_FLAVOR}-base"
    }
    args = {
        COMFYUI_VERSION = "${COMFYUI_VERSION}"
    }
    tags       = ["${DOCKER_REGISTRY_URL}comfyui-base:${notequal("nvidia", BASE_FLAVOR) ? "${BASE_FLAVOR}-" : ""}${IMAGE_LABEL}"]
    platforms  = ["linux/amd64"]
    cache-from = ["type=registry,ref=${DOCKER_REGISTRY_URL}comfyui-base:${notequal("nvidia", BASE_FLAVOR) ? "${BASE_FLAVOR}-" : ""}${IMAGE_LABEL}"]
    cache-to   = ["type=inline"]
}

target "comfyui-extensions" {
    context    = "."
    dockerfile = "dockerfile.extensions"
    contexts = {
        comfyui-base = "target:comfyui-base"
    }
    tags       = ["${DOCKER_REGISTRY_URL}comfyui-extensions:${notequal("nvidia", BASE_FLAVOR) ? "${BASE_FLAVOR}-" : ""}${IMAGE_LABEL}"]
    platforms  = ["linux/amd64"]
    cache-from = ["type=registry,ref=${DOCKER_REGISTRY_URL}comfyui-extensions:${notequal("nvidia", BASE_FLAVOR) ? "${BASE_FLAVOR}-" : ""}${IMAGE_LABEL}"]
    cache-to   = ["type=inline"]
}

target "comfyui-reactor" {
    context    = "."
    dockerfile = "dockerfile.reactor"
    contexts = {
        comfyui-extensions = "target:comfyui-extensions"
    }
    tags       = ["${DOCKER_REGISTRY_URL}comfyui-reactor:${notequal("nvidia", BASE_FLAVOR) ? "${BASE_FLAVOR}-" : ""}${IMAGE_LABEL}"]
    platforms  = ["linux/amd64"]
    cache-from = ["type=registry,ref=${DOCKER_REGISTRY_URL}comfyui-reactor:${notequal("nvidia", BASE_FLAVOR) ? "${BASE_FLAVOR}-" : ""}${IMAGE_LABEL}"]
    cache-to   = ["type=inline"]
}