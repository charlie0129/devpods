#!/usr/bin/env bash

sed -i 's@//.*archive.ubuntu.com@//mirrors.ustc.edu.cn@g' /etc/apt/sources.list.d/ubuntu.sources
# Since we are all using azure.archive.ubuntu.com, the above one has already replaced security sources.
sed -i 's/security.ubuntu.com/mirrors.ustc.edu.cn/g' /etc/apt/sources.list.d/ubuntu.sources
apt-get update
