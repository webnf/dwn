{ pkgs, lib, ... }:

{
  dev = false;
  clj = {
    aot = [ "webnf.dwn.boot" ];
    sourceDirectories = [
      ./clj
    ];
  };
  jvm.sourceDirectories = [
    ./jvm
  ];
  mvn = {
    group = "webnf";
    artifact = "dwn";
    version = "1";
    repositoryFile = ./dwn.repo.json;
    dependencies = with pkgs; [
      juds
      (deps.aether.dwn.override { dev = true; })
      # (pkgs.overrideDwn deps.expander { dev = true; })
      ["org.clojure" "test.check" "0.9.0"]
      ["org.clojure" "tools.logging" "0.3.1"]
      ["com.stuartsierra" "component" "0.3.2"]
      ["webnf.deps" "logback" "0.2.0-alpha2"]
    ];
  };
  nrepl.port = 4050;
  plugins = [ ./nrepl/module.nix ];
}
