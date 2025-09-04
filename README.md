# devpods

This repo contains images that I use with devpod.sh as development containers.

## What's special?

Using Docker inside DevPod (Docker in Docker) is really hard to setup and easy to get wrong. If you want to use GPUs in Docker in Docker, it's even harder.

This repo provides you a great starting point to achieve Docker in Docker, and optionally with NVIDIA GPUs.

Most configurations are explained in code comments. You can build custom images and modify the configurations as you wish.

## Image list

- `cuda-12.8.1`

To build a image, run `make <image-name>`. For example, to build `cuda-12.8.1`, run `make cuda-12.8.1`.

To use custom image name, `DOCKER_REPO=exmaple.com/user/devpod DOCKER_TAG_PREFIX=xxxxx- make cuda-12.8.1` will build an image `exmaple.com/user/devpod:xxxxx-cuda-12.8.1`

There are examples in `examples/`

- `devcontainers.json`: You can put this in `.devcontainer/devcontainer.json` in a directory and create a workspace from it. So you can have privileged access.
- `pod-template.yaml`: Add this to `DevPod -> Provider (Kubernetes) -> Advanced Options -> Pod Manifest Template`. So you can finetune you Kubernetes Pod yaml.