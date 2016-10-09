(ns webnf.dwn.config
  (:require [clojure.java.io :as io]
            [clojure.edn :as edn]
            [clojure.spec :as s]
            [clojure.walk :as w]
            [webnf.jvm :as jvm]
            [webnf.dwn.container :as wdc]
            [webnf.dwn.system :as wds]
            [com.stuartsierra.component :as cmp]))

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

(defn kill-container! [container]
  (print "TBD"))

(defrecord MixinContainer [parent child container]
  cmp/Lifecycle
  (start [this]
    (if container
      this
      (assoc this :container
             (jvm/->Container "mixin container" nil nil nil))))
  (stop [this]
    (if container
      (do (kill-container! container)
          (assoc this :container nil))
      this))
  wds/Updateable
  (-get-key [this] ::mixin-container)
  (-update-from [this {p' :parent c' :child :as prev}]
    (if (and (identical? parent p')
             (identical? child c'))
      this
      (do (cmp/stop prev)
          (cmp/start this)))))

(defn mixin-container [[parent child]]
  (MixinContainer. parent child nil
                   {::cmp/dependencies {:parent parent
                                        :child child}}
                   nil))

(def dwn-readers
  {'webnf.dwn.container/mixin mixin-container})

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
