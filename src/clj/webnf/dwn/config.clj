(ns webnf.dwn.config
  (:require [clojure.java.io :as io]
            [clojure.edn :as edn]
            [clojure.spec :as s]
            [clojure.walk :as w]
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
(s/def :webnf.dwn.component/container
  (s/or :container-ref ::qualified-keyword
        :container-instance (partial instance? webnf.jvm.Container)
        :container-constructor ifn?
        #_(s/fspec :args (s/cat :catalog :webnf.dwn/containers)
                   :ret ::container-instance)))

;; impl

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

(comment
  (llet [a (+ b 10)
         b 1]
        a)
  )

(declare resolve-container*)

(defn mixin-container [[parent child]]
  (fn [root]
    (resolve-container* root parent)
    (resolve-container* root child)
    (jvm/->Container "mixin container" nil nil nil)))

(def dwn-readers
  {'webnf.dwn.container/mixin mixin-container})

(defmulti instantiate* (fn [value rpath] (next rpath)))

(defmethod instantiate* :default [value rpath]
  (cond (map? value) (persistent!
                      (reduce (fn [tm k v]
                                (assoc! tm k (instantiate* v (cons k rpath))))
                              (transient {}) value))))

(defmethod instantiate* [:webnf.dwn/containers] [root [id]]
  )

(defn- container-name [id]
  (or (::name (meta id))
      (str (gensym "container-"))))

(defn- instantiate-container [{:keys [:webnf.dwn/containers] :as root} id]
  (cond (keyword? id)
        (resolve-container*
         root (vary-meta (or (get containers id)
                             (throw (ex-info (str "No container " id) {:id id :root root})))
                         assoc ::name (str id)))
        (map? id)
        (let [{:keys [classpath security-manager thread-group]} id]
          #_(wdc/container (container-name id) (instantiate-classpath classpath)
                           (instantiate-security)))
        (instance? webnf.jvm.Container id) id
        (ifn? id) (id root)))

(defn- resolve-container* [root id]
  (let [{:keys [::container-instances]} (meta root)]
    (or (get @container-instances id)
        (get (swap! container-instances instantiate-container root id) id))))

(defn config-resolve [c]
  (if (s/valid? ::root c)
    (with-meta c {::container-instances (atom {})
                  ::component-instances (atom {})})
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
