# ComfyUI Prebuilt Docker Images

This repository provides Docker build configurations that package ComfyUI together with all prerequisites, in a few different flavors. It also contains GitHub Actions definitions that can build and publish them to the GitHub Container Registry.

## Use cases

* Running on a GPU cloud provider like [RunPod](https://www.runpod.io/), [QuickPod](https://quickpod.io/), [Vast.ai](https://vast.ai/) or [TensorDock](https://tensordock.com/).
* Running locally in a stable and isolated environment.

## Motivation

The images are ready-to-run with all necessary dependencies already installed. This means that upgrading to a new version of ComfyUI simply means downloading a new image, instead of updating existing files in place. So no fear of breaking an existing installation while updating!

## Available Images

These images are currently published to the GitHub Container Registry:

| Image | Description |
|-------|-------------|
| `ghcr.io/radiatingreverberations/comfyui-base:latest` | Base ComfyUI installation |
| `ghcr.io/radiatingreverberations/comfyui-extensions:latest` | [KJNodes](https://github.com/kijai/ComfyUI-KJNodes), [GGUF](https://github.com/city96/ComfyUI-GGUF), [TeaCache](https://github.com/welltop-cn/ComfyUI-TeaCache) |
| `ghcr.io/radiatingreverberations/comfyui-reactor:latest` | [ReActor](https://github.com/Gourieff/ComfyUI-ReActor) (with model downloader) |
| `ghcr.io/radiatingreverberations/comfyui-omnigen2:latest` | [OmniGen2](https://github.com/Yuan-ManX/ComfyUI-OmniGen2) (with model downloader)|

## Running locally

ComfyUI can run inside of a container with good performance - it can access the GPU as long as the `--gpus` argument is given to Docker.

### Basic usage

```shell
docker run --gpus=all -p 8188:8188 ghcr.io/radiatingreverberations/comfyui-extensions:latest
```

### With persistent storage

Without any additional configuration, any files created from ComfyUI will be lost whenever the container is removed or recreated, such as when updating to a new version. So when running locally, you most likely want certain directories to be located outside of the container. For persistent storage, mount these directories:

| Container Path | Purpose |
|----------------|---------|
| `/comfyui/models` | Model files |
| `/comfyui/user/default` | User settings |
| `/comfyui/input` | Input images/videos |
| `/comfyui/output` | Generated outputs |

For example:

```shell
docker run --rm --gpus=all --name comfyui \
  -p 8188:8188 \
  -v ./models:/comfyui/models \
  -v ./user:/comfyui/user/default \
  -v ./input:/comfyui/input \
  -v ./output:/comfyui/output \
  ghcr.io/radiatingreverberations/comfyui-extensions:latest
```

### Additional custom nodes

If your favorite custom nodes are missing from the installation, it is possible to add them by mounting them as directories inside the `custom_nodes` folder.

### Windows specific notes

When running Docker images on Windows, it most likely runs on a Linux VM under WSL2. This means that they cannot access the Windows file systems directly, but have to use [drvfs](https://wsl.dev/technical-documentation/drvfs/). This can make models take longer to load. The workaround is to put such files on a Linux file system directly inside WSL2.

## Building

Instead of using the pre-built images it is also possible to build them locally.

```shell
docker buildx bake
```
