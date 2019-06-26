(ns webnf.dwn.mvn.reader
  (:require [clojure.java.io :as io]
            [clojure.pprint :as pp]
            [webnf.nix.data :as nix-data]))

(defn warn [fmt & args]
  (.println *err* (str "WARNING: " (apply format fmt args))))

(defn -main [& args]
  (warn "%s %s: unsure how to respond" "mvn2nix" args))

