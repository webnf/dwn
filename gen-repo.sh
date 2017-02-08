#!/bin/sh -e

EXPR="let
  pkgs = (import <nixpkgs> {}).callPackage ./src/nix/lib/clojure.nix {};
  target = pkgs.callPackage $1 {};
in target.closureRepo
"

REPO_FILE=$(nix-build --show-trace --no-out-link -E "$EXPR")

cp -f $REPO_FILE $2
