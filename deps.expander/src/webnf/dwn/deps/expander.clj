(ns webnf.dwn.deps.expander
  (:import org.eclipse.aether.util.version.GenericVersionScheme
           java.io.PushbackReader)
  (:require [clojure.java.io :as io]
            [webnf.nix.data :as data]
            [webnf.nix.aether :refer [coordinate-info]]
            [clojure.edn :as edn]
            [clojure.set :as set]))

(def gvs (GenericVersionScheme.))

(defn- compare-versions [v1 v2]
  (compare (.parseVersion gvs v1)
           (.parseVersion gvs v2)))

(defn- exclusions-pred [exclusion-set]
  (fn [{:keys [group artifact]}]
    (boolean (some (fn [excl]
                     ;; TODO classifier, extension
                     (and (= group (:group excl))
                          (= artifact (:artifact excl))))
                   exclusion-set))))

(defn- unify-versions [result coordinates fixed-coordinates repo tree-exclusions]
  (reduce (fn [r {:keys [group artifact extension classifier version
                         exclusions scope]
                  :as coordinate}]
            (let [{rv :version
                   re :exclusions} (get-in r [group artifact extension classifier])
                  version* (or (get-in fixed-coordinates [group artifact extension classifier])
                               (and rv (neg? (compare-versions version rv))
                                    rv)
                               version)
                  tree-exclusions* (set/union tree-exclusions exclusions)]
              (if (= rv version*)
                r (unify-versions (assoc-in r [group artifact extension classifier]
                                            {:version version*
                                             :exclusions (if rv
                                                           (set/intersection re exclusions)
                                                           exclusions)})
                                  (->> [group artifact extension classifier version* :dependencies]
                                       (get-in repo)
                                       (map coordinate-info)
                                       (remove (exclusions-pred tree-exclusions*)))
                                  fixed-coordinates repo
                                  tree-exclusions*))))
          result coordinates))

(defn- seen-pred [seen]
  (fn [{:keys [group artifact extension classifier]}]
    (contains? seen [group artifact extension classifier])))

(defn- expand-deps* [coordinates seen version-map repo]
  (mapcat (fn [{:keys [group artifact extension classifier]}]
            (let [{:keys [version exclusions] :as vmi} (get-in version-map [group artifact extension classifier])]
              (concat
               (when-not (contains? seen [group artifact extension classifier])
                 [[group artifact extension classifier version]])
               (expand-deps* (->> [group artifact extension classifier version]
                                  (get-in repo)
                                  :dependencies
                                  (map coordinate-info)
                                  (remove (seen-pred seen))
                                  (remove (exclusions-pred exclusions)))
                             (conj seen [group artifact extension classifier])
                             version-map repo))))
          coordinates))

(defn- provided->seen [provided]
  (transduce (map (comp vec (partial take 4)))
             conj #{} provided))

(defn expand-deps [coordinates' fixed-coordinates provided-versions repo]
  (let [coordinates (map coordinate-info coordinates')
        version-map (unify-versions {} coordinates fixed-coordinates repo #{})]
    (->> (expand-deps* coordinates (provided->seen provided-versions) version-map repo)
         reverse distinct reverse
         (mapv (fn [coord]
                 (-> (get-in repo coord)
                     (assoc :coordinate coord)
                     (dissoc :dependencies :exclusions)))))))

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

(defn -main [classpath-out-file repo-file coordinates-str fixed-coordinates-str provided-versions-str]
  (let [classpath (expand-deps (edn/read-string coordinates-str)
                               (edn/read-string fixed-coordinates-str)
                               (edn/read-string provided-versions-str)
                               (read* repo-file))]
    (with-open [o (io/writer classpath-out-file)]
      (doseq [s (data/emit-expr classpath)]
        (.write o (str s))))))
