ARG UBUNTU_VERSION=24.04
ARG DOCKER_VERSION=28.3.3

# We need to copy some files from the official dind image
FROM docker:${DOCKER_VERSION}-dind AS dind

# Our base image
FROM ubuntu:${UBUNTU_VERSION}

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update
# Don't remove lists because we may need it later during development.

############ Configure dev environments ############

# Common tools
RUN apt-get install -y \
    zsh git curl wget locales file iptables \
    htop vim gnupg numactl \
    sysstat zip unzip ca-certificates \
    python3 python3-venv python3-pip \
    sudo iotop strace screen tmux lsd btop jq zstd proxychains4 \
    rsync shellcheck socat tree openssh-server

# Build tools
RUN apt-get install -y \
    build-essential cmake ninja-build

# Locales
RUN echo "LC_ALL=en_US.UTF-8" >>/etc/environment && \
    echo "en_US.UTF-8 UTF-8" >>/etc/locale.gen && \
    echo "LANG=en_US.UTF-8" >>/etc/locale.conf && \
    locale-gen en_US.UTF-8

# Install uv
ARG UV_VERSION=0.8.15
RUN curl -LsSf https://astral.sh/uv/${UV_VERSION}/install.sh | sh

# Install Golang
ARG GO_VERSION=1.25.1
ARG TARGETPLATFORM=amd64
RUN export GOINST=go${GO_VERSION}.linux-${TARGETPLATFORM}.tar.gz && \
    wget https://go.dev/dl/${GOINST} && \
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
    wget -O docker.tgz "https://download.docker.com/linux/static/${DOCKER_CHANNEL}/${dockerArch}/docker-${DOCKER_VERSION}.tgz" && \
    tar --extract --file docker.tgz --strip-components 1 --directory /usr/local/bin/ && \
    rm docker.tgz && \
    wget -O docker-buildx "https://github.com/docker/buildx/releases/download/${BUILDX_VERSION}/buildx-${BUILDX_VERSION}.${buildx_arch}" && \
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

COPY --from=dind /usr/local/bin/modprobe /usr/local/bin/modprobe
# Tini (useful if this container is run without a init)
COPY --from=dind /usr/local/bin/docker-init /usr/local/bin/docker-init

# So we can use overlay2
VOLUME /var/lib/docker

############ Copy common scripts ############
COPY scripts/ubuntu-use-china-mirror.sh /root/bin/ubuntu-use-china-mirror.sh
COPY config/htoprc /root/.config/htop/htoprc
COPY scripts/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

# So docker daemon keeps running. devcontainer.json must have overrideCommand=false, otherwise this will not work.
ENTRYPOINT [ "/usr/local/bin/docker-init", "--", "/usr/local/bin/docker-entrypoint.sh" ]
CMD [ ]
