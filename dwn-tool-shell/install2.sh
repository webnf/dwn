#!/usr/bin/env bash

set -evx

ROOT=$HOME/.local/share/dwn
mkdir -p \
      $ROOT/{root,etc,var/run,run} \
      $ROOT/nix/var/nix/{gcroots,temproots,userpool,profiles,db} \
      $ROOT/nix/var/log/nix/drvs

export HOME=$ROOT/root
cd $ROOT

CLOSURE=$(nix-build --no-out-link -E '
with import <nixpkgs> {};
runCommand "closure" rec {
  DWN_TOOL = (callPackage /home/herwig/checkout/webnf/dwn/default.nix {}).dwnTool;
  NIX = nixUnstable;
  ZSH = zsh;
  UTILLINUX = utillinux;
  STRACE = strace;
  LESS = less;
  COREUTILS = coreutils;
  SU = su;
  exportReferencesGraph = [
    "c" DWN_TOOL
  ];
} "
  mkdir -p $out/{bin,share}
  cp c $out/share/closure
  for p in $NIX $DWN_TOOL $ZSH $UTILLINUX $STRACE $COREUTILS $LESS $SU; do
    for b in $p/bin/*; do
      if [ ! -e \"$out/bin/$(basename $b)\" ]; then
        ln -s $b $out/bin/
      fi
    done
  done
"')

rsync -rlt $(nix-store -qR $CLOSURE) $ROOT/nix/store/

#
#  --option build-users-group users

exec unshare -rmU -- sh -evxc "
mount --make-rprivate /
mount --rbind $ROOT/nix /nix
export PATH=$CLOSURE/bin
mount --rbind $ROOT/etc /etc
mount --rbind $ROOT/root /root
mount --rbind $ROOT/var /var
mount --rbind $ROOT/run /run
export NIX_REMOTE=local
export USER=root
$CLOSURE/bin/nix-store --init
$CLOSURE/bin/nix-store --register-validity < $CLOSURE/share/closure
exec zsh
"
