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
| `ghcr.io/radiatingreverberations/comfyui-ssh:latest` | [OpenSSH](https://www.openssh.com/) |

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

## Running on a cloud provider

If you were to simply open the ComfyUI port on your container, anyone on the internet will be able to connect, and all the traffic between your computer and the cloud provider would be unencrypted. One solution to this is to use the `ssh` image.

### Connecting using SSH

The `ssh` image starts an OpenSSH server on port 2222. So when running on a cloud provider, you would typically want to run a command like this:

```shell
docker run --gpus=all -p 2222:2222 ghcr.io/radiatingreverberations/comfyui-ssh:latest
```

The `ssh` image will display additional details on how to connect to the instance:

```plaintext
================================================================================
 ComfyUI + SSH Tunnel
================================================================================
 User:        u-f0f1c7f3c8d148548dc4875c330849
 SSH Port:    2222
 Host key ID: SHA256:N4woBIEaCnT0x9rCayt0OwHbOz+wW2PhJpK4AbU1URY

 Public IPv4: 123.456.789.101

 How to connect:
   ssh -p 2222 u-f0f1c7f3c8d148548dc4875c330849@123.456.789.101 -L 8188:127.0.0.1:8188

 Note! The actual IP address and port you need to connect to may be different
 depending on your hosting provider. Check their dashboard for the correct
 values if the above does not work.
================================================================================
```

### Security and configuration

By default the image will randomly generate a username and display it at startup. As this username is only known to you, no one else will be able to connect. It is also possible to configure the username by setting the `SSH_USER` environment variable:

```shell
docker run --gpus=all -e SSH_USER=u-f0f1mysecretuser0849 -p 2222:2222 ghcr.io/radiatingreverberations/comfyui-ssh:latest
```

This way you will not need to look at the console output to find it. To remain secure, ensure that the username you configure is not easy to guess. Alternatively, use key authentication by specifying your public key with `SSH_KEY`:

```shell
docker run --gpus=all -e SSH_USER=me -e SSH_KEY="ssh-ed25519 AAA...Qma" -p 2222:2222 ghcr.io/radiatingreverberations/comfyui-ssh:latest
```

Or even a password using `SSH_PASSWORD`:

```shell
docker run --gpus=all -e SSH_USER=me -e SSH_PASSWORD=extra-super-secret -p 2222:2222 ghcr.io/radiatingreverberations/comfyui-ssh:latest
```

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
