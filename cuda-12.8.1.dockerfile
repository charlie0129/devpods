FROM nvidia/cuda:12.8.1-cudnn-devel-ubuntu24.04

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update
# Don't remove lists because we may need it later during development.

############ Configure dev environments ############
# Common tools
RUN apt-get install -y \
    zsh git curl wget locales \
    build-essential cmake htop vim \
    sysstat zip unzip ca-certificates \
    python3 python3-venv python3-pip \
    sudo iotop strace screen tmux lsd btop jq zstd proxychains4 \
    rsync shellcheck socat tree \
    libibverbs-dev rdma-core infiniband-diags openssh-server perftest \
    nvtop

# Install uv
RUN curl -LsSf https://astral.sh/uv/install.sh | sh

# Locales
RUN echo "LC_ALL=en_US.UTF-8" >>/etc/environment
RUN echo "en_US.UTF-8 UTF-8" >>/etc/locale.gen
RUN echo "LANG=en_US.UTF-8" >>/etc/locale.conf
RUN locale-gen en_US.UTF-8

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

# NOTE: I haven't found a way to let the docker daemon running. So this is not working yet.

# NVIDIA Container Toolkit
# RUN curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg \
#   && curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
#     sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
#     sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
# RUN apt-get update
# RUN apt-get install -y \
#       nvidia-container-toolkit \
#       nvidia-container-toolkit-base \
#       libnvidia-container-tools \
#       libnvidia-container1

# # Docker
# COPY config/docker-daemon.json /etc/docker/daemon.json
# RUN curl -fsSL https://get.docker.io | sh
# RUN containerd config default >/etc/containerd/config.toml

# # Configure NVIDIA Container Toolkit
# RUN nvidia-ctk runtime configure --runtime=docker
# RUN nvidia-ctk runtime configure --runtime=containerd
# RUN nvidia-ctk config --set nvidia-container-cli.no-cgroups --in-place

############ Copy common scripts ############
COPY scripts/ubuntu-use-china-mirror.sh /root/bin/ubuntu-use-china-mirror.sh
COPY config/htoprc /root/.config/htop/htoprc
