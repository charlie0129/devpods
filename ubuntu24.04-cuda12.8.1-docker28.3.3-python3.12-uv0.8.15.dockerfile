ARG CUDA_VERSION=12.8.1
ARG UBUNTU_VERSION=24.04

FROM nvidia/cuda:${CUDA_VERSION}-cudnn-devel-ubuntu${UBUNTU_VERSION}

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update
# Don't remove lists because we may need it later during development.

############ Configure dev environments ############
# Common tools
RUN apt-get install -y \
    zsh git curl wget locales file \
    build-essential cmake htop vim \
    sysstat zip unzip ca-certificates \
    python3 python3-venv python3-pip \
    sudo iotop strace screen tmux lsd btop jq zstd proxychains4 \
    rsync shellcheck socat tree \
    libibverbs-dev rdma-core infiniband-diags openssh-server perftest \
    nvtop

# Locales
RUN echo "LC_ALL=en_US.UTF-8" >>/etc/environment && \
    echo "en_US.UTF-8 UTF-8" >>/etc/locale.gen && \
    echo "LANG=en_US.UTF-8" >>/etc/locale.conf && \
    locale-gen en_US.UTF-8

# Install uv
ARG UV_VERSION=0.8.15
RUN curl -LsSf https://astral.sh/uv/${UV_VERSION}/install.sh | sh

############ Configure dotfiles ############
RUN chsh -s /usr/bin/zsh

COPY build/dotfiles /root/dotfiles
RUN /root/dotfiles/bootstrap.sh -f

COPY scripts/download-z4h.zsh /root/download-z4h.zsh
# Errors like "can't change option: monitor" can be ignored because there no TTY.
# Note that you must see this error "[ERROR]: gitstatus failed to initialize." for this script to succeed.
# Yes, weirdly, you must see an error to succeed. If you don't see it during build, it doesn't work.
RUN /root/download-z4h.zsh

############ Configure docker ############

# Having the docker daemon running in devpod is not possible yet. 
# So we will rely on docker daemon from a sidecar container (see examples/pod-template.yaml).
# We will only install the docker client here.

# Theses environment variables are required to connect to the sidecar container.
ENV DOCKER_HOST=tcp://localhost:2376
ENV DOCKER_TLS_VERIFY=1
# This volume should be shared between this and the sidecar container.
ENV DOCKER_TLS_CERTDIR=/certs
ENV DOCKER_CERT_PATH=/certs/client

# Version should be the same as the docker sidecar container (see examples/pod-template.yaml).
ARG DOCKER_VERSION_STRING=5:28.3.3-1~ubuntu.24.04~noble
RUN install -m 0755 -d /etc/apt/keyrings && \
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc && \
    chmod a+r /etc/apt/keyrings/docker.asc && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" >/etc/apt/sources.list.d/docker.list && \
    apt-get update && \
    apt-get install -y docker-ce-cli=$DOCKER_VERSION_STRING docker-buildx-plugin docker-compose-plugin


############ Copy common scripts ############
COPY scripts/ubuntu-use-china-mirror.sh /root/bin/ubuntu-use-china-mirror.sh
COPY config/htoprc /root/.config/htop/htoprc

CMD [ "zsh" ]
