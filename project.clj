(defproject webnf/dwn "0-SNAPSHOT"
  :java-source-paths [ "src/jvm" ]
  :source-paths [ "src/clj" "deps.aether/src" "deps.expander/src" "nix.aether/src" "nix.data/src" ]
  :dependencies
  [[org.clojure/clojure "1.9.0-alpha16"]
   [org.clojure/test.check "0.9.0"]
   [org.clojure/tools.logging "0.3.1"]
   [com.stuartsierra/component "0.3.2"]
   [webnf.deps/logback "0.2.0-alpha2"]
   [org.apache.maven/maven-aether-provider "3.3.9"]
   [org.eclipse.aether/aether-transport-file "1.1.0"]
   [org.eclipse.aether/aether-transport-wagon "1.1.0"]
   [org.eclipse.aether/aether-connector-basic "1.1.0"]
   [org.eclipse.aether/aether-impl "1.1.0"]
   [org.apache.maven.wagon/wagon-provider-api "2.10"]
   [org.apache.maven.wagon/wagon-http "2.10"]
   [org.apache.maven.wagon/wagon-ssh "2.10"]])
