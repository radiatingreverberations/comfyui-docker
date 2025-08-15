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
        "nvidia-sageattention",
        "nvidia-nunchaku",
        "nvidia-xformers",
        "nvidia-flashattention",
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
        "comfyui-ssh"
    ]
}

target "nvidia-builder" {
    context = "."
    dockerfile = "dockerfile.nvidia.builder"
    platforms  = [ "linux/amd64" ]
    tags       = ["${DOCKER_REGISTRY_URL}nvidia-builder:latest"]
    cache-from = ["type=registry,ref=${DOCKER_REGISTRY_URL}nvidia-builder:latest"]
    cache-to   = ["type=inline"]
}

target "nvidia-sageattention" {
    context = "."
    dockerfile = "dockerfile.nvidia.sageattention"
    contexts = {
        builder = "target:nvidia-builder"
    }
    platforms  = [ "linux/amd64" ]
    tags       = ["${DOCKER_REGISTRY_URL}nvidia-builder:sageattention"]
    cache-from = ["type=registry,ref=${DOCKER_REGISTRY_URL}nvidia-builder:sageattention"]
    cache-to   = ["type=inline"]
}

target "nvidia-nunchaku" {
    context = "."
    dockerfile = "dockerfile.nvidia.nunchaku"
    contexts = {
        builder = "target:nvidia-builder"
    }
    platforms  = [ "linux/amd64" ]
    tags       = ["${DOCKER_REGISTRY_URL}nvidia-builder:nunchaku"]
    cache-from = ["type=registry,ref=${DOCKER_REGISTRY_URL}nvidia-builder:nunchaku"]
    cache-to   = ["type=inline"]
}

target "nvidia-xformers" {
    context = "."
    dockerfile = "dockerfile.nvidia.xformers"
    contexts = {
        builder = "target:nvidia-builder"
    }
    platforms  = [ "linux/amd64" ]
    tags       = ["${DOCKER_REGISTRY_URL}nvidia-builder:xformers"]
    cache-from = ["type=registry,ref=${DOCKER_REGISTRY_URL}nvidia-builder:xformers"]
    cache-to   = ["type=inline"]
}

target "nvidia-flashattention" {
    context = "."
    dockerfile = "dockerfile.nvidia.flashattention"
    contexts = {
        builder = "target:nvidia-builder"
    }
    platforms  = [ "linux/amd64" ]
    tags       = ["${DOCKER_REGISTRY_URL}nvidia-builder:flashattention"]
    cache-from = ["type=registry,ref=${DOCKER_REGISTRY_URL}nvidia-builder:flashattention"]
    cache-to   = ["type=inline"]
}

target "nvidia-base" {
    context = "."
    dockerfile = "dockerfile.nvidia.base"
    contexts = {
        sageattention  = "target:nvidia-sageattention"
        nunchaku       = "target:nvidia-nunchaku"
        xformers       = "target:nvidia-xformers"
        flashattention = "target:nvidia-flashattention"
    }
    platforms  = [ "linux/amd64" ]
    tags       = ["${DOCKER_REGISTRY_URL}comfyui-base:nvidia"]
    cache-from = ["type=registry,ref=${DOCKER_REGISTRY_URL}comfyui-base:nvidia"]
    cache-to   = ["type=inline"]
}

target "cpu-base" {
    context = "."
    dockerfile = "dockerfile.cpu.base"
    platforms  = [ "linux/amd64" ]
    tags       = ["${DOCKER_REGISTRY_URL}comfyui-base:cpu"]
    cache-from = ["type=registry,ref=${DOCKER_REGISTRY_URL}comfyui-base:cpu"]
    cache-to   = ["type=inline"]
}

target "amd-base" {
    context = "."
    dockerfile = "dockerfile.amd.base"
    platforms  = [ "linux/amd64" ]
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

target "comfyui-ssh" {
    context    = "."
    dockerfile = "dockerfile.ssh"
    contexts = {
        comfyui-extensions = "target:comfyui-extensions"
    }
    secret     = ["id=SSH_HOST_ED25519_KEY_B64,env=SSH_HOST_ED25519_KEY_B64"]
    tags       = ["${DOCKER_REGISTRY_URL}comfyui-ssh:${notequal("nvidia", BASE_FLAVOR) ? "${BASE_FLAVOR}-" : ""}${IMAGE_LABEL}"]
    platforms  = ["linux/amd64"]
    cache-from = ["type=registry,ref=${DOCKER_REGISTRY_URL}comfyui-ssh:${notequal("nvidia", BASE_FLAVOR) ? "${BASE_FLAVOR}-" : ""}${IMAGE_LABEL}"]
    cache-to   = ["type=inline"]
}