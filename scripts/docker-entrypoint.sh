#!/bin/bash

set -o errexit
set -o pipefail

if [[ -d "/workspaces" ]]; then
    echo "Changing home dir of root from /root to /workspaces/root..."
    # Note that we won't use /root as the home dir when we are running. Instead
    # the contents of /root are copied to /workspaces/root and /workspaces/root
    # is used as home, so user's changes in home are preserved across restarts.

    # We will edit the home dir manually instead of using usermod (usermod prevents us from editing logged-in user).
    install -d -m 700 -o root -g root "/workspaces/root" || {
        # Fallback on NFS PVC root squash.
        echo "Your PVC does not allow chown. Using mkdir..."
        # On NFS PVC it may fail with permission issues due to root squash, so we skip chown if install fails.
        mkdir -p "/workspaces/root"
    } 
    awk -F: -vOFS=: -v h="/workspaces/root" '$1=="root"{$6=h}1' /etc/passwd >/etc/passwd.new
    install -o root -g root -m "$(stat -c '%a' /etc/passwd)" /etc/passwd.new /etc/passwd
    rm -f /etc/passwd.new

    head -1 /etc/passwd 
    
    # Copy home
    cp -a "/root/." "/workspaces/root" || {
        # Fallback on NFS PVC root squash.
        echo "Your PVC does not allow chown. Using regular cp..."
        cp -dfR "/root/." "/workspaces/root"
    }

    export HOME=/workspaces/root
    # Bootstrap dotfiles again to fix home dir changes.
    /workspaces/root/dotfiles/bootstrap.sh -f
else
    echo "Skip change home dir because /workspaces is not present, i.e., you are not in DevPod."
fi

echo "Allowing * as safe git directory"
# Allow using any git dir. Since NFS root squash may end up with nobody:nogroup, we have to do this to use git.
git config --global --unset-all safe.directory || true # May fail with empty git config
git config --global --add safe.directory '*'

# Start docker
/usr/local/bin/dockerd
