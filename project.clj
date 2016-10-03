(defproject webnf/dwn "0-SNAPSHOT"
  :java-source-paths [ "src/jvm" ]
  :source-paths [ "src/clj" ]
  :dependencies
  [[org.clojure/clojure "1.9.0-alpha13"]
   [org.clojure/test.check "0.9.0"]
   [org.clojure/tools.logging "0.3.1"]
   [com.stuartsierra/component "0.3.1"]
   [org.slf4j/slf4j-api "1.7.13"]])
