ARG CUDA_VERSION=12.8.1
ARG UBUNTU_VERSION=24.04
ARG DOCKER_VERSION=28.3.3

# We need to copy some files from the official dind image
FROM docker:${DOCKER_VERSION}-dind AS dind

# Our base image
FROM nvidia/cuda:${CUDA_VERSION}-cudnn-devel-ubuntu${UBUNTU_VERSION}

ENV DEBIAN_FRONTEND=noninteractive

# I build image in Azure so use Azure mirrors.
RUN sed -i 's@//.*archive.ubuntu.com@//azure.archive.ubuntu.com@g' /etc/apt/sources.list.d/ubuntu.sources && \
    sed -i 's@//security.ubuntu.com@//azure.archive.ubuntu.com@g' /etc/apt/sources.list.d/ubuntu.sources && \
    rm /etc/apt/sources.list.d/cuda.list && \
    apt-get update && \
    \
    apt-get install -y \
        systemd systemd-sysv \
        zsh git git-lfs curl wget locales file iptables \
        htop vim gnupg numactl traceroute telnet apache2 \
        sysstat zip unzip ca-certificates lsof ncdu less \
        python3 python3-venv python3-pip \
        sudo iotop strace screen tmux lsd btop jq zstd proxychains4 \
        rsync shellcheck socat tree openssh-server aria2 \
        iperf iperf3 net-tools lshw pciutils usbutils ethtool \
        nmap bind9-dnsutils bind9-utils iputils-ping iproute2 \
        software-properties-common netcat-openbsd ffmpeg \
        kmod devscripts debhelper fakeroot dkms check dmidecode \
        fio wrk \
        \
        build-essential automake cmake ninja-build meson ccache gdb \
        \
        libsm6 libxext6 libgl1 python3-dev libpython3-dev \
        libopenmpi-dev libnuma1 libnuma-dev \
        libibverbs-dev libibverbs1 libibumad3 \
        librdmacm1 libnl-3-200 libnl-route-3-200 libnl-route-3-dev libnl-3-dev \
        ibverbs-providers infiniband-diags perftest \
        libgtest-dev libjsoncpp-dev libunwind-dev \
        libboost-all-dev libssl-dev \
        libgrpc-dev libgrpc++-dev libprotobuf-dev protobuf-compiler-grpc \
        pybind11-dev \
        libhiredis-dev libcurl4-openssl-dev \
        libczmq4 libczmq-dev \
        libfabric-dev \
        patchelf libsubunit0 libsubunit-dev \
        \
        libibverbs-dev rdma-core infiniband-diags perftest nvtop \
        && \
    \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    sed -i 's@//.*archive.ubuntu.com@//archive.ubuntu.com@g' /etc/apt/sources.list.d/ubuntu.sources

# Configure systemd for container use
RUN systemctl set-default multi-user.target && \
    systemctl mask dev-hugepages.mount sys-fs-fuse-connections.mount && \
    systemctl mask systemd-logind.service getty.target console-getty.service && \
    systemctl mask systemd-udev-trigger.service systemd-udevd.service && \
    systemctl mask systemd-modules-load.service kmod-static-nodes.service && \
    systemctl mask systemd-timesyncd.service systemd-resolved.service unattended-upgrades.service

############ Configure dev environments ############

# Nsight Systems
RUN curl -fsSL -o nsys.deb https://developer.nvidia.com/downloads/assets/tools/secure/nsight-systems/2025_5/NsightSystems-linux-cli-public-2025.5.1.121-3638078.deb && \
    dpkg -i nsys.deb && \
    rm nsys.deb

# Locales
RUN echo "LC_ALL=en_US.UTF-8" >/etc/environment && \
    echo "en_US.UTF-8 UTF-8" >/etc/locale.gen && \
    echo "LANG=en_US.UTF-8" >/etc/locale.conf && \
    locale-gen en_US.UTF-8

# Install uv
ARG UV_VERSION=0.8.15
RUN curl -LsSf https://astral.sh/uv/${UV_VERSION}/install.sh | sh

############ Configure dotfiles ############

RUN chsh -s /usr/bin/zsh

COPY build/dotfiles /root/dotfiles
RUN /root/dotfiles/bootstrap.sh -f

COPY scripts/download-z4h.zsh /tmp/download-z4h.zsh
# Errors like "can't change option: monitor" can be ignored because there no TTY.
# Note that you must see this error "[ERROR]: gitstatus failed to initialize." for this script to succeed.
# Yes, weirdly, you must see an error to succeed. If you don't see it during build, it doesn't work.
RUN /tmp/download-z4h.zsh && rm /tmp/download-z4h.zsh

# Note that we won't use /root as the home dir when we are running. Instead
# the contents of /root are copied to /workspaces/root and /workspaces/root
# is used as home, so user's changes in home are preserved across restarts.

# Remove history files to avoid overwriting users' history later.
RUN rm -f /root/.z /root/.*_history

############ Configure docker ############

ARG DOCKER_COMPOSE_VERSION=v2.39.2
ARG BUILDX_VERSION=v0.26.1
ARG DOCKER_CHANNEL=stable
# Already defined at the top
ARG DOCKER_VERSION

# Set iptables-legacy for Ubuntu 22.04 and newer
RUN update-alternatives --set iptables /usr/sbin/iptables-legacy

# Install Docker and buildx
RUN set -eux; \
    arch="$(uname -m)"; \
    case "$arch" in \
        x86_64) dockerArch='x86_64' ; buildx_arch='linux-amd64' ;; \
        armhf) dockerArch='armel' ; buildx_arch='linux-arm-v6' ;; \
        armv7) dockerArch='armhf' ; buildx_arch='linux-arm-v7' ;; \
        aarch64) dockerArch='aarch64' ; buildx_arch='linux-arm64' ;; \
        *) echo >&2 "error: unsupported architecture ($arch)"; exit 1 ;; \
    esac && \
    curl -fsSL -o docker.tgz "https://download.docker.com/linux/static/${DOCKER_CHANNEL}/${dockerArch}/docker-${DOCKER_VERSION}.tgz" && \
    tar --extract --file docker.tgz --strip-components 1 --directory /usr/local/bin/ && \
    rm docker.tgz && \
    curl -fsSL -o docker-buildx "https://github.com/docker/buildx/releases/download/${BUILDX_VERSION}/buildx-${BUILDX_VERSION}.${buildx_arch}" && \
    mkdir -p /usr/local/lib/docker/cli-plugins && \
    chmod +x docker-buildx && \
    mv docker-buildx /usr/local/lib/docker/cli-plugins/docker-buildx && \
    dockerd --version && \
    docker --version && \
    docker buildx version

# Install Docker Compose
RUN set -eux; \
    curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose && \
    chmod +x /usr/local/bin/docker-compose && \
    docker-compose version && \
    ln -s /usr/local/bin/docker-compose /usr/local/lib/docker/cli-plugins/docker-compose

# Install NVIDIA Container Toolkit
ARG NVIDIA_CONTAINER_TOOLKIT_VERSION=1.17.8-1
RUN curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg && \
    curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
    sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
    tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
RUN apt-get update && \
    apt-get install -y \
      nvidia-container-toolkit=${NVIDIA_CONTAINER_TOOLKIT_VERSION} \
      nvidia-container-toolkit-base=${NVIDIA_CONTAINER_TOOLKIT_VERSION} \
      libnvidia-container-tools=${NVIDIA_CONTAINER_TOOLKIT_VERSION} \
      libnvidia-container1=${NVIDIA_CONTAINER_TOOLKIT_VERSION} \
    && \
    \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Default Docker daemon config
COPY config/docker-daemon.json /etc/docker/daemon.json

# Configure NVIDIA Container Toolkit
RUN nvidia-ctk runtime configure --runtime=docker

# Copy systemd service files
COPY config/docker.service /etc/systemd/system/docker.service
COPY config/docker.socket /etc/systemd/system/docker.socket

# Create docker group
RUN groupadd -f docker

# Dummy modprobe so Docker can work
COPY --from=dind /usr/local/bin/modprobe /usr/local/bin/modprobe

# So we can use overlay2
VOLUME /var/lib/docker

############ Copy common scripts ############
COPY scripts/ubuntu-use-china-mirror.sh /root/bin/ubuntu-use-china-mirror.sh
COPY config/htoprc /root/.config/htop/htoprc

# Copy initialization script
COPY scripts/container-init.sh /usr/local/bin/container-init.sh
RUN chmod +x /usr/local/bin/container-init.sh

# Enable the initialization service
COPY config/container-init.service /etc/systemd/system/container-init.service
RUN systemctl enable container-init.service

# Use systemd directly as PID 1
ENTRYPOINT [ "/usr/sbin/init" ]
CMD [ ]
