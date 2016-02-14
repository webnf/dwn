{ callPackage, writeScript, lib, socat, fetchurl }:
{ dwn, nrepl }:

with callPackage ./util.nix {};

loadComponent dwn "nrepl" "webnf.dwn.nrepl/nrepl" nrepl (with mvnDeps; [
  (sourceDir ./nrepl-cmp) clojure toolsLogging
] ++ sets.ssCmp ++ sets.cider )
