(ns webnf.dwn.util
  (:require [clojure.java.io :as io]
            [clojure.edn :as edn]
            [clojure.spec.alpha :as s]))

(defn require-call-form
  ([sym arg] (require-call-form sym arg false identity))
  ([sym arg reload] (require-call-form sym arg reload identity))
  ([sym arg reload wrap] (require-call-form sym arg reload wrap false))
  ([sym arg reload wrap verbose]
   `(do (require '~(symbol (namespace sym))
                 ~@(when verbose [:verbose])
                 ~@(when reload [:reload-all]))
        ~(wrap (list sym arg)))))

(defn config-ref [spec]
  (s/or :kw-ref qualified-keyword? :inst spec))

(defn pass-or-require [[type data] slot]
  (case type
    :kw-ref [nil [[slot data]]]
    :inst [data nil]))

(defn guard-config! [spec data msg]
  (when-not (s/valid? spec data)
    (throw (ex-info "Invalid Config" (s/explain-data spec data)))))
