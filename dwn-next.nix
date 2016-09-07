{ callPackage, cljNsLauncher, resolveMvnDep
, configFile ? ./config.edn }:

let classpath = map resolveMvnDep [
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

in cljNsLauncher {
  name = "dwn";
  env = {
    classpath = [ (callPackage ./artefact.nix { inherit classpath; }) ] ++ classpath;
  };
  namespace = "webnf.dwn.boot";
  suffixArgs = [ "${configFile}" ];
}
