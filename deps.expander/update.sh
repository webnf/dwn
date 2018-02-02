#!/bin/sh -e

deps='[
 [ "org.clojure" "clojure" "1.9.0" ]
 [ "org.eclipse.aether" "aether-util" "1.1.0" ]
]'

TMPREPO=$(mktemp /tmp/repo.edn.XXXXXX)
trap "rm $TMPREPO" EXIT

REPO_GEN_EXPR="$(cat <<EOF
(((import <nixpkgs> {}).callPackage ../default.nix { devMode = true; })
 .callPackage ../deps.aether/lib.nix {})
.closureRepoGenerator {
  dependencies = $deps;
}
EOF
)"

DEPS_EXPAND_EXPR="$(cat <<EOF
(((import <nixpkgs> {}).callPackage ../default.nix { devMode = true; })
 .callPackage ./lib.nix {})
.depsExpander $TMPREPO $deps [] [] {}
EOF
)"

GEN=$(nix-build --no-out-link --show-trace -E "$REPO_GEN_EXPR")

$GEN $TMPREPO

EXPANDED_DEPS=$(nix-build --no-out-link --show-trace -E "$DEPS_EXPAND_EXPR")

cp "$EXPANDED_DEPS" ./deps.bootstrap.nix
