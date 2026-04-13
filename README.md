# ComfyUI Prebuilt Docker Images

This repository provides Docker build configurations that package [ComfyUI](https://github.com/comfyanonymous/ComfyUI) together with all prerequisites, in a few different flavors. It also contains GitHub Actions definitions that can build and publish them to the GitHub Container Registry.

## Use cases

* Running on a GPU cloud provider like [RunPod](https://www.runpod.io/), [QuickPod](https://quickpod.io/), [Vast.ai](https://vast.ai/) or [TensorDock](https://tensordock.com/).
* Running locally in a stable and isolated environment.

## Motivation

The images are ready-to-run with all necessary dependencies already installed. This means that upgrading to a new version of ComfyUI simply means downloading a new image, instead of updating existing files in place. So no fear of breaking an existing installation while updating!

## Automatic builds on upstream changes

The ComfyUI repository is checked periodically for updates, to ensure the images stay up to date.

||latest|master|cpu-latest|cpu-master|amd-latest|amd-master|
|------------|:------:|:------:|:----------:|:----------:|:----------:|:----------:|
|`base`|![base latest](https://img.shields.io/endpoint?url=https://gist.githubusercontent.com/radiatingreverberations/eea88cce8184a10cf25b2b09266d236a/raw/ghcr-last-updated-comfyui-base-latest.json)|![base master](https://img.shields.io/endpoint?url=https://gist.githubusercontent.com/radiatingreverberations/eea88cce8184a10cf25b2b09266d236a/raw/ghcr-last-updated-comfyui-base-master.json)|![base cpu-latest](https://img.shields.io/endpoint?url=https://gist.githubusercontent.com/radiatingreverberations/eea88cce8184a10cf25b2b09266d236a/raw/ghcr-last-updated-comfyui-base-cpu-latest.json)|![base cpu-master](https://img.shields.io/endpoint?url=https://gist.githubusercontent.com/radiatingreverberations/eea88cce8184a10cf25b2b09266d236a/raw/ghcr-last-updated-comfyui-base-cpu-master.json)|![base amd-latest](https://img.shields.io/endpoint?url=https://gist.githubusercontent.com/radiatingreverberations/eea88cce8184a10cf25b2b09266d236a/raw/ghcr-last-updated-comfyui-base-amd-latest.json)|![base amd-master](https://img.shields.io/endpoint?url=https://gist.githubusercontent.com/radiatingreverberations/eea88cce8184a10cf25b2b09266d236a/raw/ghcr-last-updated-comfyui-base-amd-master.json)|
|`extensions`|![ext latest](https://img.shields.io/endpoint?url=https://gist.githubusercontent.com/radiatingreverberations/eea88cce8184a10cf25b2b09266d236a/raw/ghcr-last-updated-comfyui-extensions-latest.json)|![ext master](https://img.shields.io/endpoint?url=https://gist.githubusercontent.com/radiatingreverberations/eea88cce8184a10cf25b2b09266d236a/raw/ghcr-last-updated-comfyui-extensions-master.json)|![ext cpu-latest](https://img.shields.io/endpoint?url=https://gist.githubusercontent.com/radiatingreverberations/eea88cce8184a10cf25b2b09266d236a/raw/ghcr-last-updated-comfyui-extensions-cpu-latest.json)|![ext cpu-master](https://img.shields.io/endpoint?url=https://gist.githubusercontent.com/radiatingreverberations/eea88cce8184a10cf25b2b09266d236a/raw/ghcr-last-updated-comfyui-extensions-cpu-master.json)|![ext amd-latest](https://img.shields.io/endpoint?url=https://gist.githubusercontent.com/radiatingreverberations/eea88cce8184a10cf25b2b09266d236a/raw/ghcr-last-updated-comfyui-extensions-amd-latest.json)|![ext amd-master](https://img.shields.io/endpoint?url=https://gist.githubusercontent.com/radiatingreverberations/eea88cce8184a10cf25b2b09266d236a/raw/ghcr-last-updated-comfyui-extensions-amd-master.json)|
|`ssh`|![ssh latest](https://img.shields.io/endpoint?url=https://gist.githubusercontent.com/radiatingreverberations/eea88cce8184a10cf25b2b09266d236a/raw/ghcr-last-updated-comfyui-ssh-latest.json)|![ssh master](https://img.shields.io/endpoint?url=https://gist.githubusercontent.com/radiatingreverberations/eea88cce8184a10cf25b2b09266d236a/raw/ghcr-last-updated-comfyui-ssh-master.json)|![ssh cpu-latest](https://img.shields.io/endpoint?url=https://gist.githubusercontent.com/radiatingreverberations/eea88cce8184a10cf25b2b09266d236a/raw/ghcr-last-updated-comfyui-ssh-cpu-latest.json)|![ssh cpu-master](https://img.shields.io/endpoint?url=https://gist.githubusercontent.com/radiatingreverberations/eea88cce8184a10cf25b2b09266d236a/raw/ghcr-last-updated-comfyui-ssh-cpu-master.json)|![ssh amd-latest](https://img.shields.io/endpoint?url=https://gist.githubusercontent.com/radiatingreverberations/eea88cce8184a10cf25b2b09266d236a/raw/ghcr-last-updated-comfyui-ssh-amd-latest.json)|![ssh amd-master](https://img.shields.io/endpoint?url=https://gist.githubusercontent.com/radiatingreverberations/eea88cce8184a10cf25b2b09266d236a/raw/ghcr-last-updated-comfyui-ssh-amd-master.json)|

## Available images

These images are currently published to the GitHub Container Registry:

|Image|Additional installed components|
|-----|-------------------------------|
|`comfyui-base`|[xFormers](https://github.com/facebookresearch/xformers), [FlashAttention-2](https://github.com/Dao-AILab/flash-attention), [SageAttention2++](https://github.com/thu-ml/SageAttention), [Nunchaku](https://github.com/nunchaku-tech/nunchaku)|
|`comfyui-extensions`|[ComfyUI-Manager](https://github.com/Comfy-Org/ComfyUI-Manager)|
|`comfyui-ssh`|[OpenSSH server](https://www.openssh.com/)|

## Available tags

|Tag|Description|
|---|-----------|
|`latest`|Latest tagged release of ComfyUI for NVIDIA / CUDA 13.0|
|`vX.Y.Z`|Latest image built for a specific tagged ComfyUI release for NVIDIA / CUDA 13.0|
|`master`|Latest commit of the ComfyUI `master` branch for NVIDIA / CUDA 13.0|
|`amd-latest` / `amd-master`|As above, but for AMD / ROCm 7.1.1|
|`cpu-latest` / `cpu-master`|As above, but a plain Ubuntu base image without GPU support|
|`amd-vX.Y.Z` / `cpu-vX.Y.Z`|Release-specific tags for AMD / ROCm 7.1.1 and CPU-only images|

Release-specific tags track the current image for that upstream ComfyUI release and may move when this repository's Docker build logic changes.

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

|Container Path|Purpose|
|--------------|-------|
|`/comfyui/models`|Model files|
|`/comfyui/user`|User settings and ComfyUI-Manager data|
|`/comfyui/input`|Input images/videos|
|`/comfyui/output`|Generated outputs|

### Persist custom nodes

When using the extensions image that includes ComfyUI-Manager, you may also want the custom nodes you install to persist across Docker image updates. Mount this additional directory:

|Container Path|Purpose|
|--------------|-------|
|`/comfyui/custom_nodes`|Custom nodes|

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
      - ./user:/comfyui/user
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

## Running on a cloud provider

If you want to run ComfyUI on a cloud provider without exposing the web UI directly, use the `ssh` image and connect through an SSH tunnel. The full setup and security notes are documented in [SSH.md](SSH.md).

## Building

Instead of using the pre-built images it is also possible to build them locally.

```shell
docker buildx bake
```

By default local builds consume:

* `ghcr.io/offloadr/base/cpu-core:py3.12-torch2.10.0-cpu`
* `ghcr.io/offloadr/base/amd-core:py3.12-torch2.10.0-rocm7.1.1`
* `ghcr.io/offloadr/base/nvidia-full:py3.12-torch2.10.0-cuda13.0.2`

To override them, pass one or more Bake variables such as `CPU_BASE_IMAGE`, `AMD_BASE_IMAGE`, or `NVIDIA_BASE_IMAGE`.

## Image details

### ComfyUI base image

* [ComfyUI](https://github.com/comfyanonymous/ComfyUI)
* [HuggingFace CLI](https://huggingface.co/docs/huggingface_hub/guides/cli)

### ComfyUI extensions image

* [git](https://git-scm.com/)
* [ComfyUI Manager](https://github.com/comfy-org/ComfyUI#comfyui-manager)

### ComfyUI SSH image

* [OpenSSH](https://www.openssh.org/)
* [curl](https://curl.se/)
* [rsync](https://rsync.samba.org/)
