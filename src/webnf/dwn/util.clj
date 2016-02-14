(ns webnf.dwn.util
  (:require [clojure.java.io :as io]
            [clojure.edn :as edn]))

(defn require-call-form
  ([sym arg] (require-call-form sym arg false identity))
  ([sym arg reload] (require-call-form sym arg reload identity))
  ([sym arg reload wrap]
   `(do (require '~(symbol (namespace sym)) ~@(when reload [:reload-all]))
        ~(wrap (list sym arg)))))

(def classpath-list (partial map (comp io/as-url (partial str "file:"))))

(def read-cp (comp classpath-list line-seq io/reader))

(def dwn-readers
  (assoc default-data-readers
         'jvm.classpath/list classpath-list
         'jvm.classpath/file read-cp))

(defn dwn-read [src]
  (edn/read
   {:readers dwn-readers}
   (java.io.PushbackReader.
    (io/reader src))))
