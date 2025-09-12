#!/bin/bash

set -o errexit
set -o pipefail

if [[ -d "/workspaces" ]]; then
    echo "Changing home dir of root from /root to /workspaces/root..."
    # Note that we won't use /root as the home dir when we are running. Instead
    # the contents of /root are copied to /workspaces/root and /workspaces/root
    # is used as home, so user's changes in home are preserved across restarts.

    # We will edit the home dir manually instead of using usermod (usermod prevents us from editing logged-in user).
    install -d -m 700 -o root -g root "/workspaces/root" || mkdir -p "/workspaces/root" # On NFS PVC it may fail with permission issues due to root squash, so we skip chown if install fails.
    awk -F: -vOFS=: -v h="/workspaces/root" '$1=="root"{$6=h}1' /etc/passwd >/etc/passwd.new
    install -o root -g root -m "$(stat -c '%a' /etc/passwd)" /etc/passwd.new /etc/passwd
    rm -f /etc/passwd.new

    head -1 /etc/passwd 
    
    # Copy home
    cp -a "/root/." "/workspaces/root" || cp -dfR "/root/." "/workspaces/root" # Fallback on NFS PVC root squash.

    export HOME=/workspaces/root
    # Bootstrap dotfiles again to fix home dir changes.
    /workspaces/root/dotfiles/bootstrap.sh -f
else
    echo "Skip change home dir because /workspaces is not present, i.e., you are not in DevPod."
fi

# Start docker
/usr/local/bin/dockerd
