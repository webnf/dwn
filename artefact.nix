{ callPackage, runCommand, jdk, lib
, dwn, nix-list, get, keyword, symbol, extract
, renderClasspath, resolveMvnDep
, cljCompile, jvmCompile, combinePathes
, meta ? { dwn = { group = "webnf"; name = "dwn"; version = "DEVEL"; }; } }:

dwn.build {
  inherit (meta.dwn) group name version;
  dependencies = [
      ["org.clojure" "clojure"]
      ["org.clojure" "tools.logging"]
      ["javax.servlet" "javax.servlet-api"]
      ["ch.qos.logback" "logback-classic"]
      ["ch.qos.logback" "logback-core"]
      ["org.slf4j" "slf4j-api"]
      ["org.slf4j" "log4j-over-slf4j"]
      ["org.slf4j" "jcl-over-slf4j"]
      ["org.slf4j" "jul-to-slf4j"]
      ["com.stuartsierra" "component"]
      ["com.stuartsierra" "dependency"]
    ];
  source-paths = [ ./src/clj ];
  java-source-paths = [ ./src/jvm ];
  aot = [ "webnf.dwn.boot" ];
}
