(ns webnf.dwn.mvn.reader
  (:require [clojure.java.io :as io]
            [clojure.pprint :as pp]
            [webnf.nix.data :as nix-data])
  (:import
   org.apache.maven.model.io.xpp3.MavenXpp3Reader))

(defn read-model [path]
  (with-open [rdr (io/reader path)]
    (.read (MavenXpp3Reader.) rdr)))

(def exclusion
  (juxt #(.getGroupId %)
        #(.getArtifactId %)))

(defn coord [dep]
  (let [e (.getExclusions dep)
        s (.getScope dep)
        p (cond-> {}
            (seq e) (assoc "exclusions" (mapv exclusion e))
            s       (assoc "scope" s))]
    (cond-> [(.getGroupId dep)
             (.getArtifactId dep)
             (.getType dep)
             (str (.getClassifier dep))
             (.getVersion dep)]
      (not (empty? p)) (conj p))))

(defn plugin [plug]
  (let [d (.getDependencies plug)
        p (cond-> {}
            (seq d) (assoc "dependencies" (mapv coord d)))]
    (cond-> [(.getGroupId plug)
             (.getArtifactId plug)
             (.getVersion plug)]
      (not (empty? p)) (conj p))))

(defn info [path]
  (let [model (read-model path)
        build (.getBuild model)]
    {:group (.getGroupId model)
     :name (.getArtifactId model)
     :version (.getVersion model)
     :build {:plugins (mapv plugin (.getPlugins build))}
     :dependencies (mapv coord (.getDependencies model))}))

(comment

  (bean (:build (info "/home/herwig/.m2/repository/org/clojure/clojure/1.10.1/clojure-1.10.1.pom")))
  (info "/home/herwig/checkout/clojure/pom.xml")

  (.getParent (read-model "/home/herwig/checkout/clojure/pom.xml"))

  )

(defn warn [fmt & args]
  (.println *err* (str "WARNING: " (apply format fmt args))))

(defn -main [& [op path :as  args]]
  (case op
    "pr-compile-deps" (->> path info :dependencies
                           (filterv (fn [[_ _ _ _ _ {:strs [scope]}]]
                                      (nil? scope)))
                           nix-data/nixprn)
    (warn "%s %s: unsure how to respond" "mvn2nix" args)))
