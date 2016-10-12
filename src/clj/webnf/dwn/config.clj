(ns webnf.dwn.config
  (:require [clojure.pprint :refer [pprint]]
            [clojure.java.io :as io]
            [clojure.edn :as edn]
            [clojure.spec :as s]
            [clojure.walk :as w]
            [webnf.jvm :as jvm]
            [webnf.dwn.container :as wdc]
            [webnf.dwn.system :as wds]
            [webnf.jvm.threading :as wjt]
            [com.stuartsierra.component :as cmp]
            [clojure.string :as str]))

(defprotocol ContainerConfig
  (classpath-for [cfg])
  (security-manager-for [cfg])
  (thread-group-for [cfg]))

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
  (s/or
   :base-config (s/keys :req-un [::classpath])
   :instance #(satisfies? ContainerConfig %)))

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

(defrecord MixinContainer [name parent child container]
  ContainerConfig
  (classpath-for [_] (concat (classpath-for parent)
                             (classpath-for child)))
  (security-manager-for [_]
    (security-manager-for child))
  (thread-group-for [_]
    (thread-group-for child))
  cmp/Lifecycle
  (start [this]
    (if container
      this
      (assoc this :container
             (wdc/mixin name (map :url (classpath-for child)) parent
                        (security-manager-for this)
                        (thread-group-for this)))))
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

(defn mixin-container [[parent child name]]
  (MixinContainer. (or name (gensym "mixin-"))
                   parent child nil
                   {::cmp/dependencies {:parent parent
                                        :child child}}
                   nil))

(defrecord BaseContainer [name classpath security-manager thread-group container]
  ContainerConfig
  (classpath-for [_]
    classpath)
  (security-manager-for [_]
    security-manager)
  (thread-group-for [_]
    thread-group)
  cmp/Lifecycle
  (start [this]
    (if container
      this
      ;; FIXME instantiate security-manager and thread-group here?
      ;; interactions with kill-container!
      (assoc this :container
             (wdc/container name (map :uri classpath)
                            security-manager thread-group))))
  (stop [this]
    (if container
      (do (kill-container! container)
          (assoc this container nil))
      this))
  wds/Updateable
  (-get-key [_] ::base-container)
  (-update-from [this {cp :classpath sm :security-manager
                       tg :thread-group :as prev}]
    (if (and (= classpath cp)
             (identical? thread-group tg)
             (identical? security-manager sm))
      this
      (do (cmp/stop prev)
          (cmp/start this)))))

(defn base-container [{:keys [name classpath security-manager thread-group]
                       :or {name (gensym "container-")
                            security-manager wdc/default-security-manager}}]
  (->BaseContainer name classpath security-manager
                   (or thread-group
                       (wjt/thread-group (gensym (str name "-tg-"))))))

(def dwn-readers
  {'webnf.dwn.container/mixin mixin-container})

(defn config-resolve [c]
  (let [res (s/conform ::root c)]
    (if (s/invalid? res)
      (do
        (s/explain ::root c)
        (throw (ex-info "Invalid config" (s/explain-data ::root c))))
      res)))

(defn dir-url [path]
  (io/as-url (str "file:" path (when-not (str/ends-with? path "/") "/"))))

(defn jar-url [path]
  (io/as-url (str "file:" path)))

(defrecord ClasspathEntry [name version urls])

(defn config-classpath [cp]
  (for [{name :name
         [type config] :entry} cp]
    (->ClasspathEntry
     name (:version config)
     (case type
       :source-dirs (map dir-url (:source-dirs config))
       :jar-file [(jar-url (:jar-file config))]))))

(defn config-containers [containers]
  (into {} (for [[name [type container]] containers]
             [name (case type
                     :base-config (base-container
                                   (update container :classpath
                                           config-classpath))
                     :instance container)])))

(defn config-components [components]
  (->
   (into {} (for [[name {:keys []}]]))
   (cmp/using [:webnf.dwn/containers])))

(defn config-root [{:keys [:webnf.dwn/containers
                           :webnf.dwn/components]
                    :as res}]
  (pprint res)
  {:webnf.dwn/containers (config-containers containers)
   :webnf.dwn/components (config-components components)})

(def config-read
  (comp
   config-root
   config-resolve
   (partial edn/read {:readers (merge default-data-readers
                                      dwn-readers)})
   #(java.io.PushbackReader. %)
   io/reader))
