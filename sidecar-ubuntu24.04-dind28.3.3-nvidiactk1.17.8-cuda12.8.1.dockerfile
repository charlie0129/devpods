ARG DOCKER_VERSION=28.3.3
ARG CUDA_VERSION=12.8.1
ARG UBUNTU_VERSION=24.04

FROM docker:${DOCKER_VERSION}-dind AS dind

# Technically, we don't need CUDA, just the driver should be enough.
# However, since we are already pulling the entire CUDA develelopment image in the DevPod container,
# it won't hurt to use a larger base image (no additional downloads), as long as it's the same as DevPod container.
FROM nvidia/cuda:${CUDA_VERSION}-cudnn-devel-ubuntu${UBUNTU_VERSION}

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y curl

# NVIDIA Container Toolkit
ARG NVIDIA_CONTAINER_TOOLKIT_VERSION=1.17.8-1
RUN curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg && \
    curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
    sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
    tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
RUN apt-get update
RUN apt-get install -y \
      nvidia-container-toolkit=${NVIDIA_CONTAINER_TOOLKIT_VERSION} \
      nvidia-container-toolkit-base=${NVIDIA_CONTAINER_TOOLKIT_VERSION} \
      libnvidia-container-tools=${NVIDIA_CONTAINER_TOOLKIT_VERSION} \
      libnvidia-container1=${NVIDIA_CONTAINER_TOOLKIT_VERSION}

# Docker

COPY config/docker-daemon.json /etc/docker/daemon.json
RUN curl -fsSL https://get.docker.io >/tmp/docker-install.sh && chmod +x /tmp/docker-install.sh && \
  /tmp/docker-install.sh --version ${DOCKER_VERSION} && rm /tmp/docker-install.sh

# Configure NVIDIA Container Toolkit
RUN nvidia-ctk runtime configure --runtime=docker
RUN nvidia-ctk config --set nvidia-container-cli.no-cgroups --in-place

COPY --from=dind /usr/local/bin/dockerd-entrypoint.sh /usr/local/bin/dockerd-entrypoint.sh
COPY --from=dind /usr/local/bin/docker-init /usr/local/bin/docker-init

ENTRYPOINT ["dockerd-entrypoint.sh"]
