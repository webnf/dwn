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

(defn coordinate-info [[a1 a2 & [a3 a4 a5] :as args]]
  ;; [group' artifact' extension' classifier' version' :as args]
  (case (count args)
    2 [a1 a1 "jar" "" a2]
    3 [a1 a2 "jar" "" a3]
    4 [a1 a2 a3 "" a4]
    5 [a1 a2 a3 a4 a5]))

(defn dependency-coordinate-info [spec]
  (coordinate-info (if (map? (last spec))
                     (butlast spec) spec)))

(defn- unify-versions [result coordinates fixed-coordinates repo]
  (reduce (fn [r [group artifact extension classifier version :as coordinate]]
            (let [rv (get-in r [group artifact extension classifier])
                  version* (or (get-in fixed-coordinates [group artifact extension classifier])
                               (and rv (neg? (compare-versions version rv))
                                    rv)
                               version)]
              (if (= rv version*)
                r (unify-versions (assoc-in r [group artifact extension classifier] version*)
                                  (map dependency-coordinate-info
                                       (get-in repo [group artifact extension classifier version* :dependencies]))
                                  fixed-coordinates repo))))
          result coordinates))

(defn- expand-deps* [coordinates seen version-map repo]
  (mapcat (fn [[group art ext cls _]]
            (let [version (get-in version-map [group art ext cls])]
              (cons [group art ext cls]
                    (expand-deps* (remove
                                   (fn [[group art ext cls _]]
                                     (contains? seen [group art ext cls]))
                                   (map dependency-coordinate-info
                                        (get-in repo [group art ext cls version :dependencies])))
                                  (conj seen [group art ext cls])
                                  version-map repo))))
          coordinates))

(defn expand-deps [coordinates' fixed-coordinates repo]
  (let [coordinates (map coordinate-info coordinates')
        version-map (unify-versions {} coordinates fixed-coordinates repo)]
    (->> (expand-deps* coordinates #{} version-map repo)
         reverse distinct reverse
         (mapv (fn [[g a e c :as ga]]
                 (let [v (get-in version-map ga)
                       coord [g a e c v]
                       desc (get-in repo coord)]
                   (-> desc
                       (assoc :coordinate coord)
                       (dissoc :dependencies))))))))

(defn read* [f]
  (with-open [i (PushbackReader. (io/reader f))]
    (edn/read i)))

(comment (defn warn [fmt & args]
           (.println *err* (str "WARNING: " (apply format fmt args))))

         (defn merge-descriptors [versions version {:keys [sha1 dependencies resolved-version files] :as descriptor}]
           (let [{old-sha1 :sha1
                  old-files :files
                  old-dependencies :dependencies}
                 (get versions version {})]
             (when (and old-sha1 sha1)
               (warn "Overriding sha1: %s -> %s" old-sha1 sha1))
             (when old-files
               (warn "Overriding entry with files: %s" (pr-str files)))
             descriptor))

         (defn merge-overlay [repo overlay]
           (reduce-kv
            (fn [r group artifacts]
              (assoc
               r group
               (reduce-kv
                (fn [a artifact versions]
                  (assoc
                   a artifact
                   (reduce-kv
                    merge-descriptors
                    (get a artifact {}) versions)))
                (get r group {}) artifacts)))
            repo overlay)))

(defn -main [classpath-out-file repo-file coordinates-str fixed-coordinates-str]
  (let [classpath (expand-deps (edn/read-string coordinates-str)
                               (edn/read-string fixed-coordinates-str)
                               (read* repo-file))]
    (with-open [o (io/writer classpath-out-file)]
      (doseq [s (data/emit-expr classpath)]
        (.write o (str s))))))
