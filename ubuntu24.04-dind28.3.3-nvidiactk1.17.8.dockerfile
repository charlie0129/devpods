ARG DOCKER_VERSION=28.3.3
ARG UBUNTU_VERSION=noble

FROM docker:${DOCKER_VERSION}-dind AS dind

FROM cruizba/ubuntu-dind:${UBUNTU_VERSION}-${DOCKER_VERSION}

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y curl gnupg

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

# Configure NVIDIA Container Toolkit
RUN nvidia-ctk runtime configure --runtime=docker
RUN nvidia-ctk config --set nvidia-container-cli.no-cgroups --in-place

COPY --from=dind /usr/local/bin/dockerd-entrypoint.sh /usr/local/bin/dockerd-entrypoint.sh
COPY --from=dind /usr/local/bin/docker-init /usr/local/bin/docker-init

ENTRYPOINT [ "/usr/local/bin/dockerd-entrypoint.sh" ]
