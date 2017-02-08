{ project, callPackage }:

project {

  name = "dwn";

  devMode = true;

  cljSourceDirs = [ ./src/clj ];
  javaSourceDirs = [ ./src/jvm ];

  mainNs = {
    dwn = "webnf.dwn.boot";
  };
  aot = [ "webnf.dwn.boot" ];
  compilerOptions = {
    directLinking = true;
    elideMeta = [ ":line" ":file" ":doc" ":added" ];
  };

  dependencies = [
    ["org.clojure" "clojure" "1.9.0-alpha14"]
    ["org.clojure" "test.check" "0.9.0"]
    ["org.clojure" "tools.logging" "0.3.1"]
    ["com.stuartsierra" "component" "0.3.2"]
    ["webnf.deps" "logback" "0.2.0-alpha1"]
    ["webnf" "juds" "CUSTOM"]
  ];

  overlayRepo = {
    "webnf"."juds"."jar".""."CUSTOM" = {
      files = [ "${callPackage ./juds.nix {}}/lib" ];
    };
  };

  closureRepo = ./repo.edn;

}
