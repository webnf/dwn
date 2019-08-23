{ pkgs, lib, ... }:

{
  dev = true;
  clj = {
    aot = [ "webnf.dwn.boot" ];
    sourceDirectories = [
      ./clj
    ];
  };
  jvm.sourceDirectories = [
    ./jvm
  ];
  mvn.repositoryFile = ./dwn.repo.edn;
  mvn.dependencies = with pkgs; [
    clojure juds
    ["org.clojure" "test.check" "0.9.0"]
    ["org.clojure" "tools.logging" "0.3.1"]
    ["com.stuartsierra" "component" "0.3.2"]
    ["webnf.deps" "logback" "0.2.0-alpha2"]
  ];
  plugins = [ ./nrepl/module.nix ];
}
