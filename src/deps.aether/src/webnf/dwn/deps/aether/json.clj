(ns webnf.dwn.deps.aether.json
  (:require [clojure.edn :as edn]
            [clojure.java.io :as io]))

(defn map-emitter [indent value-emitter]
  (fn [m]
    (concat
     ["{"]
     (apply concat
            (interpose
             [","]
             (map (fn [[k v]]
                    (list* indent " \"" k "\":" (value-emitter v)))
                  (sort m))))
     [indent "}"])))

(defn flat-map-emitter [key-emitter value-emitter]
  (fn [m]
    (concat
     ["{"]
     (apply concat
            (interpose
             [", "]
             (map (fn [[k v]]
                    (concat
                     (key-emitter k)
                     (cons ":" (value-emitter v))))
                  (sort m))))
     ["}"])))

(defn map-keyed-emitter [indent & {:as key-emitters}]
  (let [emitters (sort key-emitters)]
    (fn [m]
      (concat
       ["{"]
       (apply concat
              (interpose
               [","]
               (filter
                some?
                (map (fn [[k emitter]]
                       (when (contains? m k)
                         (list* indent " \"" (name k) "\":" (emitter (get m k)))))
                     emitters))))
       [indent "}"]))))

(defn list-emitter [indent value-emitter]
  (fn [l]
    (concat
     ["[" indent " "]
     (apply concat
            (interpose
             ["," indent " "]
             (map value-emitter l))
            #_(interpose
               [","]
               (map (fn [el]
                      (list* indent (value-emitter el)))
                    l)))
     [indent "]"])))

(defn flat-list-emitter [value-emitter]
  (fn [l]
    (concat
     ["["]
     (apply concat
            (interpose
             [", "]
             (map value-emitter l)))
     ["]"])))

(declare emit-generic)
(let [le (flat-list-emitter #'emit-generic)
      me (flat-map-emitter #'emit-generic #'emit-generic)]
  (defn emit-generic [o]
    (cond
      (string? o) [(pr-str o)]
      (instance? clojure.lang.Named o) [(pr-str (name o))]
      (map? o) (me o)
      (or (seq? o)
          (vector? o)) (le o)
      :else (throw (ex-info "don't know how to emit" {:o o})))))

(def emitter
  (->>
   (map-keyed-emitter
    "\n     "
    :sha1 emit-generic
    :dependencies (comp (list-emitter
                         "\n      "
                         (flat-list-emitter emit-generic))
                        sort)
    :resolved-coordinate (flat-list-emitter emit-generic))
   (map-emitter "\n    ")
   (map-emitter "\n   ")
   (map-emitter "\n  ")
   (map-emitter "\n ")
   (map-emitter "\n")))

(defn emit-repo [o]
  (emitter o))

(defn -main [edn-repo-file json-out-file]
  (with-open [r (java.io.PushbackReader. (io/reader edn-repo-file))
              w (io/writer json-out-file)]
    (doseq [s (emit-repo (edn/read r))]
      (.write w (str s)))
    #_(.write w (pr-str (emit-repo (edn/read r))))
    (.write w "\n"))
  (System/exit 0))

