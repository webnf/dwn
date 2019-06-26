#!/usr/bin/env bash

set -evx

ROOT=$HOME/.local/share/dwn
mkdir -p \
      $ROOT/{root,etc,var/run,run} \
      $ROOT/nix/var/nix/{gcroots,temproots,userpool,profiles,db} \
      $ROOT/nix/var/log/nix/drvs

export HOME=$ROOT/root

export CLOSURE=$(nix-build --show-trace --no-out-link -E '
with import <nixpkgs> {};
runCommand "closure" rec {
  exportReferencesGraph = [
    "c" (import ./closure.nix)
  ];
} "cp c $out"')

rsync -rlt $(nix-store -qR $CLOSURE) $ROOT/nix/store/

#
#  --option build-users-group users

SYSTEM=$(nix-build --no-out-link ./closure.nix)
exec unshare -mU -- zsh
exec unshare -rmU -- sh -evxc "
mount --make-rprivate /
mount --rbind $ROOT/nix /nix
export PATH=$SYSTEM/sw/bin
mount --rbind $ROOT/etc /etc
mount --rbind $ROOT/root /root
mount --rbind $ROOT/var /var
mount --rbind $ROOT/run /run
export NIX_REMOTE=local?root=/home/herwig/.local/share/dwn
#export USER=root
#nix-store --init
#nix-store --register-validity < $CLOSURE
exec zsh
"
