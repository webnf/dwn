#!/usr/bin/env bash

set -evx

ROOT=$HOME/.local/share/dwn
mkdir -p $ROOT/{nix,root,etc}

export HOME=$ROOT/root
cd $ROOT

unshare -rmU bash -c "mount --rbind $ROOT/etc /etc && mount --rbind $ROOT/nix /nix && . /nix/store/gy4yv67gv3j6in0lalw37j353zdmfcwm-nix-1.11.16/etc/profile.d/nix.sh && exec /nix/store/hqi64wjn83nw4mnf9a5z9r4vmpl72j3r-bash-4.4-p12/bin/bash"

#  && . /nix/install"
