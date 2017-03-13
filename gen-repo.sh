#!/bin/sh -e"

REPO_FILE=$(nix-build --show-trace --no-out-link shell.nix -A $1.closureRepo)

exec cp -f $REPO_FILE $2
