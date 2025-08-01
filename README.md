# ComfyUI Prebuilt Docker Images

This repository provides Docker build configurations that package [ComfyUI](https://github.com/comfyanonymous/ComfyUI) together with all prerequisites, in a few different flavors. It also contains GitHub Actions definitions that can build and publish them to the GitHub Container Registry.

## Use cases

* Running on a GPU cloud provider like [RunPod](https://www.runpod.io/), [QuickPod](https://quickpod.io/), [Vast.ai](https://vast.ai/) or [TensorDock](https://tensordock.com/).
* Running locally in a stable and isolated environment.

## Motivation

The images are ready-to-run with all necessary dependencies already installed. This means that upgrading to a new version of ComfyUI simply means downloading a new image, instead of updating existing files in place. So no fear of breaking an existing installation while updating!

## Available images

These images are currently published to the GitHub Container Registry:

| Image | Description |
|-------|-------------|
| `ghcr.io/radiatingreverberations/comfyui-base:latest` | [SageAttention2++](https://github.com/thu-ml/SageAttention), [Nunchaku](https://github.com/mit-han-lab/nunchaku) |
| `ghcr.io/radiatingreverberations/comfyui-extensions:latest` | [ComfyUI-Manager](https://github.com/Comfy-Org/ComfyUI-Manager) |
| `ghcr.io/radiatingreverberations/comfyui-reactor:latest` | [ReActor](https://github.com/Gourieff/ComfyUI-ReActor) (with model downloader) |

## Available tags

| Tag | Description | Flavor |
| --- | ------------| ------ |
| `latest` | Latest tagged release of ComfyUI | PyTorch 2.8.0rc1 / CUDA 12.8 |
| `master` | Latest commit of the `master` branch | PyTorch 2.8.0rc1 / CUDA 12.8 |
| `amd-latest` | Latest tagged release of ComfyUI | PyTorch 2.8.0rc1 / ROCm 6.4 |
| `amd-master` | Latest commit of the `master` branch | PyTorch 2.8.0rc1 / ROCm 6.4 |
| `cpu-latest` | Latest tagged release of ComfyUI | PyTorch 2.8.0rc1 / CPU |
| `cpu-master` | Latest commit of the `master` branch | PyTorch 2.8.0rc1 / CPU |

## Running locally

### Basic usage

```shell
docker run --gpus=all -p 8188:8188 ghcr.io/radiatingreverberations/comfyui-extensions:latest
```

### Additional options

Additional arguments will be forwarded to ComfyUI. For example, to enable SageAttention:

```shell
docker run --gpus=all -p 8188:8188 ghcr.io/radiatingreverberations/comfyui-extensions:latest --use-sage-attention
```

### With persistent storage

Without any additional configuration, any files created from ComfyUI will be lost whenever the container is removed or recreated, such as when updating to a new version. So when running locally, you most likely want certain directories to be located outside of the container. For persistent storage, mount these directories:

| Container Path | Purpose |
|----------------|---------|
| `/comfyui/models` | Model files |
| `/comfyui/user/default` | User settings |
| `/comfyui/input` | Input images/videos |
| `/comfyui/output` | Generated outputs |

### Persist custom nodes

When using the extensions image that includes ComfyUI-Manager, you may also want the custom nodes you install to persist across Docker image updates. Mount this additional directory:

| Container Path | Purpose |
|----------------|---------|
| `/comfyui/custom_nodes` | Custom nodes |

Note that it is not recommended to update ComfyUI itself using ComfyUI-Manager - update to a later version of the Docker image instead.

### Using Docker Compose

An example of putting it all together using [Docker Compose](https://docs.docker.com/compose/):

```yaml
services:
  comfyui:
    image: ghcr.io/radiatingreverberations/comfyui-extensions:latest
    container_name: comfyui
    command:
      - --use-sage-attention
    ports:
      - "8188:8188"
    volumes:
      - ./models:/comfyui/models
      - ./user:/comfyui/user/default
      - ./input:/comfyui/input
      - ./output:/comfyui/output
      - ./custom_nodes:/comfyui/custom_nodes
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: all
              capabilities: [gpu]
    restart: unless-stopped
```

### Windows specific notes

When running Docker images on Windows, it most likely runs on a Linux VM under WSL2. This means that they cannot access the Windows file systems directly, but have to use [drvfs](https://wsl.dev/technical-documentation/drvfs/). This can make models take longer to load. The workaround is to put such files on a Linux file system directly inside WSL2.

## Building

Instead of using the pre-built images it is also possible to build them locally.

```shell
docker buildx bake
```

## Image details

### ComfyUI base image

* [ComfyUI](https://github.com/comfyanonymous/ComfyUI)
* [HuggingFace CLI](https://huggingface.co/docs/huggingface_hub/guides/cli)
* [uv 0.7.16](https://docs.astral.sh/uv/)
* [PyTorch 2.8.0rc1](https://dev-discuss.pytorch.org/t/pytorch-2-8-rc1-produced-for-pytorch/3087)

### NVIDIA base image

NVIDIA CUDA runtime image: [12.8.1-runtime-ubuntu24.04](https://gitlab.com/nvidia/container-images/cuda/blob/master/dist/12.8.1/ubuntu24.04/runtime/Dockerfile), Python 3.12, git and additional components:

* [SageAttention2++](https://github.com/woct0rdho/SageAttention.git)
* [Nunchaku](https://github.com/mit-han-lab/nunchaku.git)

### AMD base image

AMD ROCm runtime image: [6.4.1-dev-ubuntu24.04](https://github.com/ROCm/ROCm-docker/blob/release-6.4.1/dev/Dockerfile-ubuntu-24.04)

### ComfyUI extensions image

* [KJNodes](https://github.com/kijai/ComfyUI-KJNodes)
* [GGUF](https://github.com/city96/ComfyUI-GGUF)
* [TeaCache](https://github.com/welltop-cn/ComfyUI-TeaCache)
* [Nunchaku](https://github.com/mit-han-lab/ComfyUI-nunchaku)
