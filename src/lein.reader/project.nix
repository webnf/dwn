{ lib, project, devMode, clojure }:

project rec {
  group = "webnf.dwn";
  name = "lein.reader";
  inherit devMode;

  cljSourceDirs = [ ./src ../nix.data/src ];
  compilerOptions = if !devMode then {
    directLinking = true;
    elideMeta = [ ":line" ":file" ":doc" ":added" ];
  } else {};

  dependencies = [
    ["org.clojure" "clojure" "1.9.0"]
    ["leiningen" "leiningen" "2.8.1"]
  ];
  aot = lib.optionals (!devMode) [ "webnf.dwn.lein.reader" ];
  mainNs.lein2nix = "webnf.dwn.lein.reader";

  closureRepo = ./repo.edn;

}
