#!/bin/sh -e

exec `nix-build --show-trace --no-out-link shell.nix -A $1.closureRepoGenerator` $2
