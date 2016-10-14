(ns webnf.dwn.config
  (:require [clojure.pprint :refer [pprint]]
            [clojure.java.io :as io]
            [clojure.edn :as edn]
            [clojure.spec :as s]
            [clojure.walk :as w]
            [webnf.jvm :as jvm :refer [eval-in-container]]
            [webnf.dwn.component :as wdcmp]
            [webnf.dwn.container :as wdc]
            [webnf.dwn.system :as wds]
            [webnf.jvm.threading :as wjt]
            [com.stuartsierra.component :as cmp]
            [clojure.string :as str]
            [webnf.dwn.util :refer [require-call-form config-ref]]
            [clojure.tools.logging :as log]))

(comment
  (defn- lazy-body [v-sym f-sym body]
    `(~f-sym []
      (let [cv# @~v-sym]
        (case cv#
          ::init (try
                   (vreset! ~v-sym ::on-stack)
                   (vreset! ~v-sym (do ~@body))
                   (catch Throwable e#
                     (vreset! ~v-sym ::error)
                     (throw e#)))
          ::error (throw (ex-info "No result due to previous error" {:f '~f-sym}))
          ::on-stack (throw (ex-info "Infinite recursion" {:f '~f-sym}))
          cv#))))

  (defn rewrite-symbols-to-calls [f-map body]
    (w/postwalk (fn [data]
                  (if (contains? f-map data)
                    (list (f-map data))
                    data))
                body))

  (defmacro llet [bindings & body]
    (let [inits (into {} (map vec (partition 2 bindings)))
          v-syms (into {} (map (juxt identity gensym) (keys inits)))
          lazify (partial rewrite-symbols-to-calls (set (keys inits)))]
      `(let [~@(mapcat
                #(list % `(volatile! ::init))
                (vals v-syms))]
         (letfn [~@(for [[f-sym init] inits]
                     (lazy-body (v-syms f-sym) f-sym (lazify [init])))]
           ~@(lazify body)))))
  (llet [a (+ b 10)
         b 1]
        a)
  )

(def dwn-readers
  {'webnf.dwn/container #'wdc/container
   'webnf.dwn/component #'wdcmp/container-component
   'webnf.dwn/ns-launcher #'wdcmp/launcher-component})

(def config-read
  (comp
   (partial apply cmp/system-map)
   (partial apply concat)
   #(-> % ;; FIXME check classloader compat here
        (assoc-in [:webnf.dwn/app-loader :class-loader] wdc/app-loader)
        (assoc-in [:webnf.dwn/base-loader :class-loader] wdc/base-loader))
   (partial edn/read {:readers (merge default-data-readers
                                      dwn-readers)})
   #(java.io.PushbackReader. %)
   io/reader))
