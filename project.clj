(defproject webnf/dwn "0-SNAPSHOT"
  :java-source-paths [ "src/jvm" ]
  :source-paths [ "src/clj" "deps.aether/src" "deps.expander/src" "nix.aether/src" "nix.data/src" ]
  :plugins [[cider/cider-nrepl "0.19.0"]]
  :dependencies
  [[org.clojure/clojure "1.10.0"]
   [org.clojure/test.check "0.9.0"]
   [org.clojure/tools.logging "0.3.1"]
   [com.stuartsierra/component "0.3.2"]
   [webnf.deps/logback "0.2.0-alpha2"]
   [org.apache.maven/maven-resolver-provider "3.6.0"]
   [org.apache.maven.resolver/maven-resolver-transport-file "1.3.1"]
   [org.apache.maven.resolver/maven-resolver-transport-wagon "1.3.1"]
   [org.apache.maven.resolver/maven-resolver-connector-basic "1.3.1"]
   [org.apache.maven.resolver/maven-resolver-impl "1.3.1"]
   [org.apache.maven.wagon/wagon-provider-api "3.2.0"]
   [org.apache.maven.wagon/wagon-http "3.2.0"]
   [org.apache.maven.wagon/wagon-ssh "3.2.0"]])
