{ callPackage, writeScript, lib, socat, fetchurl, dwn, cfg }:

with callPackage ./util.nix {};

commandRunner dwn "nrepl" (
  loadComponentCommand "nrepl" "webnf.dwn.nrepl/nrepl" cfg.dwn.nrepl (listClassPath (with mvnDeps; [
    (sourceDir ./nrepl-cmp) clojure toolsLogging
  ] ++ sets.ssCmp ++ sets.cider))
)
