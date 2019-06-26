#!/usr/bin/env zsh
set -evx

ROOT=$HOME/.local/share/dwnix
mkdir -p $ROOT

if [ ! -d $ROOT/nix ]; then
    (cd $ROOT
     curl https://nixos.org/releases/nix/nix-2.1.3/nix-2.1.3-x86_64-linux.tar.bz2 \
         | tar -xj
     mv nix-2.1.3-x86_64-linux nix)
fi

nix=$(find $ROOT -name "*-nix-2.1.3")

exec unshare -rmU -- sh -evxc "
mount --make-rprivate /
mkdir -p $ROOT/nix/store/g2yk54hifqlsjiha3szr4q3ccmdzyrdv-glibc-2.27 $ROOT/nix/store/y4fvhv34m1cnlvhj6bfdyqfv60a47l7i-source
mount --bind /nix/store/g2yk54hifqlsjiha3szr4q3ccmdzyrdv-glibc-2.27 $ROOT/nix/store/g2yk54hifqlsjiha3szr4q3ccmdzyrdv-glibc-2.27
mount --bind /nix/store/y4fvhv34m1cnlvhj6bfdyqfv60a47l7i-source $ROOT/nix/store/y4fvhv34m1cnlvhj6bfdyqfv60a47l7i-source
mount --rbind $ROOT/nix /nix
# exec ./revertuid $nix/bin/nix-store --init
# exec ./revertuid $nix/bin/nix-store --load-db < /nix/.reginfo
# exec ./revertuid $nix/bin/nix-store --load-db < /nix/.reginfo
exec ./revertuid-1000 $nix/bin/nix-build /etc/nixos/pkgs -A bash
"
