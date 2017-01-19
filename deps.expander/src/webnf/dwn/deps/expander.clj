(ns webnf.dwn.deps.expander
  (:import org.eclipse.aether.util.version.GenericVersionScheme
           java.io.PushbackReader)
  (:require [clojure.java.io :as io]
            [webnf.nix.data :as data]
            [clojure.edn :as edn]))

(def gvs (GenericVersionScheme.))

(defn- compare-versions [v1 v2]
  (compare (.parseVersion gvs v1)
           (.parseVersion gvs v2)))

(defn- unify-versions [result coordinates fixed-versions repo]
  (reduce (fn [r [group artifact version :as desc]]
            (let [rv (get-in r [group artifact])
                  version* (or (get-in fixed-versions [group artifact])
                               (and rv (neg? (compare-versions version rv))
                                    rv)
                               version)]
              (if (= rv version*)
                r (unify-versions (assoc-in r [group artifact] version*)
                                  (:dependencies (get-in repo [group artifact version*]))
                                  fixed-versions repo))))
          result coordinates))


(defn- expand-deps* [coordinates seen version-map repo]
  (mapcat (fn [[group art _]]
            (let [version (get-in version-map [group art])]
              (cons [group art]
                    (expand-deps* (remove
                                   (fn [[group art _]]
                                     (get seen [group art]))
                                   (:dependencies (get-in repo [group art version])))
                                  (conj seen [group art])
                                  version-map repo))))
          coordinates))

(defn expand-deps [coordinates fixed-versions repo]
  (let [version-map (unify-versions {} coordinates fixed-versions repo)]
    (->> (expand-deps* coordinates #{} version-map repo)
         reverse distinct reverse
         (mapv (fn [[g a :as ga]]
                 (let [coord [g a (get-in version-map ga)]]
                   (-> (get-in repo coord)
                       (assoc :coordinate coord)
                       (dissoc :dependencies))))))))

(defn read* [f]
  (with-open [i (PushbackReader. (io/reader f))]
    (edn/read i)))

(defn -main [classpath-out-file coordinates-file repo-file & [fixed-versions-file]]
  (let [classpath (expand-deps (read* coordinates-file)
                               (if fixed-versions-file
                                 (read* fixed-versions-file)
                                 {})
                               (read* repo-file))]
    (with-open [o (io/writer classpath-out-file)]
      (doseq [s (data/emit-expr classpath)]
        (.write o (str s))))))
