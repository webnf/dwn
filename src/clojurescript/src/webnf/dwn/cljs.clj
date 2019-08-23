(ns webnf.dwn.cljs
  (:require [cljs.build.api :as bapi]
            [clojure.edn :as edn]
            [clojure.java.io :as io]))

(defn build [path opts]
  (println "Building in" (.getAbsolutePath (java.io.File. ".")))
  (println "Path" (pr-str path))
  (println "Opts" (pr-str opts))
  #_(println (io/resource "hdnews/x/ui/base.cljc"))
  #_(println (pr-str (System/getProperty "java.class.path")))
  (bapi/build (apply bapi/inputs path) opts))

(defn -main [path opts]
  (build (edn/read-string path)
         (edn/read-string opts)))

