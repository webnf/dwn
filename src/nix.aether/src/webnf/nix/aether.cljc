(ns webnf.nix.aether
  (:require [clojure.string :as str]))

(defn- exclusion-info- [[a1 & [a2] :as args]
                        {:strs [extension classifier]
                         :or {extension "*"
                              classifier "*"}}]
  (let [[g a] (case (count args)
                1 [a1 a1]
                2 [a1 a2])]
    {:group g
     :artifact a
     :extension extension
     :classifier classifier}))

(defn exclusion-info [spec]
  (cond
    (or (symbol? spec) (string? spec))
    (exclusion-info- [(str spec)] {})
    (map? (last spec))
    (exclusion-info- (butlast spec) (last spec))
    :else
    (exclusion-info- spec {})))

(defn- coordinate-info- [[a1 a2 & [a3 a4 a5] :as args]
                         {:strs [exclusions scope optional]
                          :or {exclusions #{} scope "compile" optional false}}]
  (let [[g a e c v]
        (case (count args)
          2 [a1 a1 "jar" "" a2]
          3 [a1 a2 "jar" "" a3]
          4 [a1 a2 a3 "" a4]
          5 [a1 a2 a3 a4 a5])]
    {:group g
     :artifact a
     :extension e
     :classifier c
     :version v
     :exclusions (into #{} (map exclusion-info) exclusions)
     :scope scope
     :optional optional}))

(defn coordinate-info [spec]
  (cond
    (map? spec)
    spec
    (map? (last spec))
    (coordinate-info- (butlast spec) (last spec))
    :else
    (coordinate-info- spec {})))

(def ^:private co-str-j
  (juxt :group :artifact :extension :classifier :version))

(defn coordinate-string
  "Produces a coordinate string with a format of
   <groupId>:<artifactId>[:<extension>[:<classifier>]]:<version>>
   given a lein-style dependency spec.  :extension defaults to jar."
  [spec]
  (->> (co-str-j spec)
       (remove str/blank?)
       (interpose \:)
       (apply str)))
