(ns webnf.dwn.deps.expander
  (:import org.eclipse.aether.util.version.GenericVersionScheme
           java.io.PushbackReader)
  (:require [clojure.java.io :as io]
            [webnf.nix.data :as data]
            [webnf.nix.aether :refer [coordinate-info]]
            [clojure.edn :as edn]
            [clojure.set :as set]))

(defn warn [fmt & args]
  (.println *err* (str "WARNING: " (apply format fmt args))))

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
                   re :exclusions
                   rex :extension
                   rcl :classifier
                   :as have-result} (get-in r [group artifact])
                  [extension* classifier* version*] (or (get-in fixed-coordinates [group artifact])
                                                        [extension classifier
                                                         (or (and rv (neg? (compare-versions version rv))
                                                                  rv)
                                                             version)])]
              (let [exclusions* (if have-result
                                  (set/intersection re exclusions)
                                  exclusions)]
                (if (and (not have-result)
                         (= rv version*)
                         (= re exclusions*))
                  r (let [tree-exclusions* (set/union tree-exclusions exclusions*)]
                      (unify-versions (assoc-in r [group artifact]
                                                {:version version*
                                                 :exclusions exclusions*
                                                 :extension extension*
                                                 :classifier classifier*})
                                      (->> [group artifact extension* classifier* version* :dependencies]
                                           (get-in repo)
                                           (map coordinate-info)
                                           (remove (exclusions-pred tree-exclusions*)))
                                      fixed-coordinates repo
                                      tree-exclusions*))))))
          result coordinates))

(defn- seen-pred [seen]
  (fn [{:keys [group artifact extension classifier]}]
    (contains? seen [group artifact])))

(defn- expand-deps* [coordinates seen version-map repo tree-exclusions]
  (mapcat (fn [{:keys [group artifact] :as coord}]
            #_(when-not ((exclusions-pred tree-exclusions) coord))
            (let [{:keys [version exclusions extension classifier] :as vmi}
                  (get-in version-map [group artifact])
                  tree-exclusions* (set/union tree-exclusions exclusions)]
              (concat
               (when-not (contains? seen [group artifact])
                 [[group artifact extension classifier version]])
               (expand-deps* (->> [group artifact extension classifier version]
                                  (get-in repo)
                                  :dependencies
                                  (map coordinate-info)
                                  #_(remove (seen-pred seen))
                                  (remove (exclusions-pred tree-exclusions*)))
                             (conj seen [group artifact])
                             version-map repo
                             tree-exclusions*))))
          coordinates))

(defn- provided->seen [provided]
  (into #{}
        (comp (map coordinate-info)
              (map (juxt :group :artifact))
              (map vec))
        provided))

(defn expand-deps [coordinates' fixed-coordinates' provided-versions repo]
  (let [coordinates (map coordinate-info coordinates')
        fixed-coordinates (reduce (fn [c fc]
                                    (let [{:keys [group artifact extension classifier version]}
                                          (coordinate-info fc)]
                                      (assoc-in c [group artifact] [extension classifier version])))
                                  {} fixed-coordinates')
        version-map (unify-versions {} coordinates fixed-coordinates repo #{})]
    (->> (expand-deps* coordinates (provided->seen provided-versions) version-map repo #{})
         reverse distinct reverse
         (mapv (fn [coord]
                 (-> (get-in repo coord)
                     (assoc :coordinate coord)
                     (dissoc :dependencies :exclusions)))))))

(defn read* [f]
  (with-open [i (PushbackReader. (io/reader f))]
    (edn/read i)))

(defn tree-level-kxf [kxf]
  (fn
    ([s] (kxf s))
    ([s p v] (reduce-kv
              (fn [s' k v']
                (kxf s' (cons k p) v'))
              s v))))

(defn map-keys
  ([f] (fn [kxf]
         (fn
           ([s] (kxf s))
           ([s k v] (kxf s (f k v) v))))))

(def repo-kxf (comp (map-keys (fn [k _] (cons k ())))
                    tree-level-kxf tree-level-kxf  tree-level-kxf tree-level-kxf))

(defn transduce-kv [kxf f s m]
  (let [f* (kxf f)]
    (f* (reduce-kv f* s m))))

(defn merge-overlay [repo overlay]
  (transduce-kv
   repo-kxf
   (fn
     ([r] r)
     ([r [version classifier extension artifact group :as p]
       {:strs [sha1 dirs jar dependencies] :as desc}]
      ;; (warn "Overriding [%s/%s \"%s\"]:\n  %s" group artifact version (pr-str desc))
      (assoc-in r [group artifact extension classifier version]
                {:sha1 sha1 :dirs dirs :jar jar :dependencies dependencies})))
   repo overlay))

(defn -main [classpath-out-file repo-file coordinates-str fixed-coordinates-str provided-versions-str overlay-repo-str]
  ;; (warn "EXPANDER: %s %s \n %s" classpath-out-file repo-file overlay-repo-str)
  (let [classpath (expand-deps (edn/read-string coordinates-str)
                               (edn/read-string fixed-coordinates-str)
                               (edn/read-string provided-versions-str)
                               (merge-overlay (read* repo-file)
                                              (edn/read-string overlay-repo-str)))]
    (with-open [o (io/writer classpath-out-file)]
      (doseq [s (data/emit-expr classpath)]
        (.write o (str s))))))
