(ns webnf.dwn.system
  (:require [clojure.tools.logging :as log]
            [com.stuartsierra.component :as cmp
             :refer [Lifecycle stop start]]
            [clojure.set :as set]
            [com.stuartsierra.dependency :as dep])
  (:import com.stuartsierra.component.SystemMap))

(defprotocol Updateable
  "Builds on top of components to allow them to shortcut stop-start cycles"
  (-get-key [u] "update-from will only be called if get-key result matches")
  (-update-from [u prev] "return result as if start had been called, but allowed to reuse state from previous instance. Must do the equivalent of stop on parts of the state, that it doesn't reuse"))

(defn update-from [updated previous]
  (if (= (-get-key updated)
         (-get-key previous))
    (-update-from updated previous)
    (do (stop previous)
        (start updated))))

(defn update-system-from*
  [system prev component-keys]
  (let [graph (cmp/dependency-graph system component-keys)]
    (reduce (fn [system key]
              (assoc system key
                     (-> (@#'cmp/get-component system key)
                         (@#'cmp/assoc-dependencies system)
                         (@#'cmp/try-action system key update-from [prev]))))
            system
            (sort (dep/topo-comparator graph) component-keys))))

(defn update-system-from
  ([system prev] (update-system-from system (keys system)
                                     prev   (keys prev)))
  ([system system-keys prev prev-keys]
   (let [sk (set system-keys)
         pk (set prev-keys)
         started (set/difference sk pk)
         stopped (set/difference pk sk)
         updated (set/intersection pk sk)]
     (println "Starting" started "; Stopping" stopped "; Updating" updated)
     (cmp/stop-system prev stopped)
     (update-system-from* system prev updated))))

(extend-protocol Updateable
  nil
  (-get-key [_] ::nil)
  (-update-from [_ _] nil)
  Object
  (-get-key [o] ::generic)
  (-update-from [o prev]
    (stop prev)
    (start o))
  SystemMap
  (-get-key [o] ::system-map)
  (-update-from [o prev]
    (update-system-from o prev)))

(defrecord ServiceConfig [config-root base-container component-catalog used-containers]
  Lifecycle
  (start [_])
  (stop  [_])
  Updateable
  (-get-key [_] ::service-config)
  (-update-from [_ prev]
    ))

(defn container-catalog [containers]
  (into {} (for [{:keys [id classpath components] :as cnt} containers
                 :let [container {:id id :classpath classpath}]
                 {:keys [id start-fn] :as cmp} components]
             [id (assoc cmp :webnf.dwn.component/container container)])))

(defn service-config [{:as config-root
                       {:as used-containers
                        :keys [webnf.dwn.container/base-container]}
                       :webnf.dwn/containers
                       declared-containers :webnf.dwn.catalog/containers}]
  (->ServiceConfig
   (dissoc config-root :webnf.dwn/containers :webnf.dwn.catalog/containers)
   base-container
   (container-catalog declared-containers)
   (dissoc used-containers :webnf.dwn.container/base-container)))
