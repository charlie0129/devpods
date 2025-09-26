ARG UBUNTU_VERSION=24.04
ARG DOCKER_VERSION=28.3.3

# We need to copy some files from the official dind image
FROM docker:${DOCKER_VERSION}-dind AS dind

# Our base image
FROM ubuntu:${UBUNTU_VERSION}

ENV DEBIAN_FRONTEND=noninteractive

# I build image in Azure so use Azure mirrors.
RUN sed -i 's@//.*archive.ubuntu.com@//azure.archive.ubuntu.com@g' /etc/apt/sources.list.d/ubuntu.sources && \
    sed -i 's@//security.ubuntu.com@//azure.archive.ubuntu.com@g' /etc/apt/sources.list.d/ubuntu.sources && \
    apt-get update && \
    \
    apt-get install -y \
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
        fio wrk supervisor shadowsocks-libev \
        \
        build-essential automake ninja-build meson ccache gdb \
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

# Install newer versions of cmake (versions in apt are too old)
RUN CMAKE_VERSION=4.1.1 \
    && ARCH=$(uname -m) \
    && CMAKE_INSTALLER="cmake-${CMAKE_VERSION}-linux-${ARCH}" \
    && curl -fsSL "https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}/${CMAKE_INSTALLER}.tar.gz" -o ${CMAKE_INSTALLER}.tar.gz \
    && tar -xzf "${CMAKE_INSTALLER}.tar.gz" \
    && cp -r "${CMAKE_INSTALLER}/bin/"* /usr/local/bin/ \
    && cp -r "${CMAKE_INSTALLER}/share/"* /usr/local/share/ \
    && rm -rf "${CMAKE_INSTALLER}" "${CMAKE_INSTALLER}.tar.gz"

ARG SINGBOX_VERSION=1.12.8
RUN export INSTALLER=sing-box-${SINGBOX_VERSION}-linux-$(dpkg --print-architecture) && \
    curl -fsSL https://github.com/SagerNet/sing-box/releases/download/v${SINGBOX_VERSION}/$INSTALLER.tar.gz -o sing-box.tar.gz && \
    tar zxf sing-box.tar.gz && \
    mv $INSTALLER/sing-box /usr/local/bin && \
    rm -rf sing-box*

############ Configure dev environments ############


# Locales
RUN echo "LC_ALL=en_US.UTF-8" >/etc/environment && \
    echo "en_US.UTF-8 UTF-8" >/etc/locale.gen && \
    echo "LANG=en_US.UTF-8" >/etc/locale.conf && \
    locale-gen en_US.UTF-8

# Install uv
ARG UV_VERSION=0.8.15
RUN curl -LsSf https://astral.sh/uv/${UV_VERSION}/install.sh | sh

# Install Golang
ARG GO_VERSION=1.25.1
ARG TARGETPLATFORM=amd64
RUN export GOINST=go${GO_VERSION}.linux-${TARGETPLATFORM}.tar.gz && \
    curl -fsSL -o ${GOINST} https://go.dev/dl/${GOINST} && \
    tar -C /usr/local -xzf ${GOINST} && \
    rm -f ${GOINST}
# No need to set Golang into PATH because it's already in dotfiles.

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

# Default Docker daemon config
COPY config/docker-daemon.json /etc/docker/daemon.json

# Create docker group
RUN groupadd -f docker

# Dummy modprobe so Docker can work
COPY --from=dind /usr/local/bin/modprobe /usr/local/bin/modprobe

# So we can use overlay2
VOLUME /var/lib/docker

############ Copy common scripts ############
COPY scripts/ubuntu-use-china-mirror.sh /root/bin/ubuntu-use-china-mirror.sh
COPY config/htoprc /root/.config/htop/htoprc

# Tini (useful if this container is run without a init)
COPY --from=dind /usr/local/bin/docker-init /usr/local/bin/tini

# Copy initialization scripts
COPY scripts/prepare-root.sh /usr/local/bin/prepare-root.sh

# Supervisord config
COPY config/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Use a init
ENTRYPOINT [ "/usr/local/bin/tini", "-s", "-g", "sh", "--", "-c", "/usr/local/bin/prepare-root.sh && exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf" ]
CMD [ ]
