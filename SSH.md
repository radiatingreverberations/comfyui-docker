# ComfyUI SSH Image

If you were to simply open the ComfyUI port on your container, anyone on the internet will be able to connect, and all the traffic between your computer and the cloud provider would be unencrypted. One solution to this is to use the `ssh` image.

## Connecting using SSH

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
 Host key ID: SHA256:svSLAqHOM1w/Z2K9vSkssXHUcp6+XVtrqyUp4Wfgres

 Public IPv4: 123.456.789.101

 How to connect:
   ssh -p 2222 u-f0f1c7f3c8d148548dc4875c330849@123.456.789.101 -L 8188:127.0.0.1:8188

 Note! The actual IP address and port you need to connect to may be different
 depending on your hosting provider. Check their dashboard for the correct
 values if the above does not work.
================================================================================
```

## Security and configuration

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

Note: The published SSH image uses a static (pinned) host key. Its SHA256 fingerprint is printed at startup; verify it on first connect and expect it to remain unchanged across restarts and updates.

## Download workflow models

A simple script for downloading model files on the host is provided in the `ssh` image. After connecting over SSH, save the workflow you want to use from the UI. Then run something like:

```bash
download_workflow_models.py user/default/workflows/t2i-qwen.json
```

This works with workflows containing model links, such as those provided as templates in ComfyUI.
