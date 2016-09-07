(ns webnf.dwn.util
  (:require [clojure.java.io :as io]
            [clojure.edn :as edn]
            [webnf.jvm :refer [->Container]]
            [webnf.dwn.container :as cont]))

(defn require-call-form
  ([sym arg] (require-call-form sym arg false identity))
  ([sym arg reload] (require-call-form sym arg reload identity))
  ([sym arg reload wrap]
   `(do (require '~(symbol (namespace sym)) ~@(when reload [:reload-all]))
        ~(wrap (list sym arg)))))

(def classpath-list (partial map (comp io/as-url (partial str "file:"))))

(def read-cp (comp classpath-list line-seq io/reader))

(defn read-container [{:keys [:webnf.dwn.container/name
                              :webnf.dwn.container/classpath
                              :webnf.dwn.container/parent-classloader
                              :webnf.dwn.container/security-manager
                              :webnf.dwn.container/thread-group]}]
  (->Container name
               (cont/url-classloader classpath (or parent-classloader
                                                   cont/base-loader))
               (or security-manager cont/default-security-manager)
               (or thread-group (ThreadGroup. name))))

(def dwn-readers
  (assoc default-data-readers
         'jvm.classpath/list classpath-list
         'jvm.classpath/file read-cp
         'webnf.dwn/container read-container))

(defn dwn-read [src]
  (edn/read
   {:readers dwn-readers}
   (java.io.PushbackReader.
    (io/reader src))))

(defn config-read [src]
  (edn/read
   {:default tagged-literal
    :readers {}}
   (java.io.PushbackReader. (io/reader src))))
