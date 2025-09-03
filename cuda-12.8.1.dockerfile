FROM nvidia/cuda:12.8.1-cudnn-devel-ubuntu24.04

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update
# Don't remove lists because we may need it later during development.

############ Configure dev environments ############
# Common tools
RUN apt-get install -y \
    zsh git curl wget \
    build-essential cmake htop vim \
    sysstat zip unzip ca-certificates \
    python3 python3-venv python3-pip \
    sudo iotop strace screen tmux lsd btop jq zstd proxychains4 \
    rsync shellcheck socat tree \
    libibverbs-dev rdma-core infiniband-diags openssh-server perftest \
    nvtop
# Install uv
RUN curl -LsSf https://astral.sh/uv/install.sh | sh

############ Configure dotfiles ############
RUN chsh -s /usr/bin/zsh

COPY build/dotfiles /root/dotfiles
RUN /root/dotfiles/bootstrap.sh -f

COPY scripts/download-z4h.zsh /root/download-z4h.zsh
# Errors like "can't change option: monitor" can be ignored because there no TTY.
# Note that you must see this error "[ERROR]: gitstatus failed to initialize." for this script to succeed.
# Yes, weirdly, you must see an error to succeed. If you don't see it during build, it doesn't work.
RUN /root/download-z4h.zsh

############ Copy common scripts ############
COPY scripts/ubuntu-use-china-mirror.sh /root/bin/ubuntu-use-china-mirror.sh
