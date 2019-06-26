{ lib, project, devMode, clojure, callPackage }:

project rec {
  group = "webnf.dwn";
  name = "mvn.reader";
  inherit devMode;

  cljSourceDirs = [ ./src ../nix.data/src ];
  compilerOptions = if !devMode then {
    directLinking = true;
    elideMeta = [ ":line" ":file" ":doc" ":added" ];
  } else {};

  dependencies = [
    ["org.clojure" "clojure" "1.10.1"]
    ["org.apache.maven" "maven-model" "3.6.1"]
  ];
  aot = lib.optionals (!devMode) [ "webnf.dwn.mvn.reader" ];
  mainNs.mvn2nix = "webnf.dwn.mvn.reader";
  plugins = [(callPackage ../nrepl-project.nix { devMode = false; })];

  closureRepo = ./repo.edn;

}
