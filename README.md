# devpods

This repo contains images that I use with devpod.sh as development containers.

## What's special?

Using Docker inside DevPod (Docker in Docker) is really hard to setup and easy to get wrong. If you want to use GPUs in Docker in Docker, it's even harder.

This repo provides you with a great starting point to achieve Docker in Docker, and optionally with NVIDIA GPUs.

Most configurations are well-explained in code comments. You can build custom images and modify the configurations as you wish.

## Workspace Examples

### What examples are provided?

Examples can be found in `examples/`.

1. `cuda-docker`: CUDA development with Docker in Docker. You can access GPUs both in the development environment and Docker containers started inside the development environment. InfiniBand is supported too.
2. `docker`: basic Docker in Docker development environment. No GPU in this one.

### How to use examples?

1. Download and install DevPods client from devpod.sh
2. Add a Kubernetes provider. Provide your kubeconfig as usual. You don't need to change any setting now.
3. Set `Advanced Options -> Pod Manifest Template` to the absolute path of `<this-repo>/examples/<example-name>/pod-template.yaml`
4. Create a Workspace. Set `Workspace Source` to `Folder` with a path of `<this-repo>/examples/<example-name>`. This step makes use of the `.devcontainer/` configuration directory. If you want to use your own directory, just copy `.devcontainer/` to your directory.
5. Wait for the DevPod to start. Note that the images used are large, it may take a while.

All examples are thoroughly commented so go ahead and read the files in them, change any settings as needed. If you changed settings, you will need to create a new workspace to see the effect.

## Image list

To achieve DinD with GPU, I used custom base images with DevPod. You can search for `*.dockerfile` in this project root to see what images are available.

- `ubuntu24.04-cuda12.8.1-docker28.3.3-python3.12-uv0.8.15`: just as the name suggestd, it's based on Ubuntu 24.04 with CUDA 12.8.1 development environment, Docker in Docker 28.3.3, Python 3.12, and UV 0.8.15.
- `ubuntu24.04-docker28.3.3-golang1.25.1-python3.12-uv0.8.15`: this one is a pure-CPU image, based on Ubuntu 24.04 with Docker in Docker 28.3.3, Golang 1.25.1, Python 3.12 and UV 0.8.15

All image has basic build tools available (e.g. gcc, g++, make).

To build a image, run `make <image-name>`. For example, to build `ubuntu24.04-cuda12.8.1-docker28.3.3-python3.12-uv0.8.15`, run `make ubuntu24.04-cuda12.8.1-docker28.3.3-python3.12-uv0.8.15`.

To use custom image name, `DOCKER_REPO=exmaple.com/user/devpod DOCKER_TAG_PREFIX=xxxxx- make <image-name>` will build an image with name `exmaple.com/user/devpod:xxxxx-<image-name>`. This is useful if you want to push images to private repositories.
