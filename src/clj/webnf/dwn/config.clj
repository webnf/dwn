(ns webnf.dwn.config
  (:require [clojure.java.io :as io]
            [clojure.edn :as edn]
            [clojure.spec :as s]
            [webnf.jvm :as jvm]
            [webnf.dwn.container :as wdc]))

;; lib

(s/def ::qualified-keyword
  (s/and keyword? namespace))

(s/def ::qualified-symbol
  (s/and symbol? namespace))

;; Config root

(s/def ::root
  (s/keys :req [:webnf.dwn/containers :webnf.dwn/components]))

(s/def :webnf.dwn/containers
  (s/map-of ::qualified-keyword ::container))

(s/def ::container
  (s/keys :req-un [::classpath]))

(s/def ::classpath
  (s/* (s/cat :name  ::qualified-symbol
              :entry ::classpath-entry)))

(s/def ::classpath-entry
  (s/or :source-dirs (s/keys :req-un [::version ::source-dirs])
        :jar-file    (s/keys :req-un [::version ::jar-file])))

(s/def ::version string?)
(s/def ::source-dirs (s/coll-of string?))
(s/def ::jar-file string?)

(s/def :webnf.dwn/components
  (s/map-of ::qualified-keyword ::component))

(s/def ::component
  (s/keys :req-un [:webnf.dwn.component/container]
          :opt-un [:webnf.dwn.component/factory
                   :webnf.dwn.component/config]))
(s/def :webnf.dwn.component/factory symbol?)
(s/def :webnf.dwn.component/config any?)
(s/def ::container-instance (partial instance? webnf.jvm.Container))
(s/def :webnf.dwn.component/container
  (s/or :container-ref ::qualified-keyword
        :container-instance ::container-instance
        :container-constructor (s/fspec :args (s/cat :catalog :webnf.dwn/containers)
                                        :ret ::container-instance)))

;; impl

(defn mixin-container [stack]
  (jvm/->Container "mixin container" nil nil nil))

(def dwn-readers
  {'webnf.dwn.container/mixin mixin-container})

(defn- resolve-container* [{:keys [:webnf.dwn/containers]} id]
  (cond (keyword? id)
        (let [{:keys [classpath security-manager thread-group]}
              (get containers id)]
          ;; WIP
          )
        (instance? webnf.dwn.Container id) id
        (ifn? id) (id containers)))

(defn config-resolve [c]
  (if (s/valid? ::root c)
    c
    (do
      (s/explain ::root c)
      (throw (ex-info "Invalid config" (s/explain-data ::root c))))))

(def config-read
  (comp
   config-resolve
   (partial edn/read {:readers (merge default-data-readers
                                      dwn-readers)})
   #(java.io.PushbackReader. %)
   io/reader))
