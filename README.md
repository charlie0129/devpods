# devpods

This repo contains images that I use with devpod.sh as development containers.

Image list:

- `cuda-12.8.1`

To build a image, run `make <image-name>`. For example, to build `cuda-12.8.1`, run `make cuda-12.8.1`.

To use custom image name, `DOCKER_REPO=exmaple.com/user/devpod DOCKER_TAG_PREFIX=xxxxx- make cuda-12.8.1` will build an image `exmaple.com/user/devpod:xxxxx-cuda-12.8.1`

There are examples in `examples/`

- `devcontainers.json`: You can put this in `.devcontainer/devcontainer.json` in a directory and create a workspace from it. So you can have privileged access.
- `pod-template.yaml`: Add this to `DevPod -> Provider (Kubernetes) -> Advanced Options -> Pod Manifest Template`. So you can finetune you Kubernetes Pod yaml.