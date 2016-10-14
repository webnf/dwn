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
    (do (log/info (-get-key updated) "updating" previous "->" updated)
        (-update-from updated previous))
    (do (log/info previous (-get-key previous) "stop" updated (-get-key updated) "start")
        (stop previous)
        (start updated))))

(defn update-system-from*
  [system prev started-keys updated-keys]
  (let [component-keys (set/union started-keys updated-keys)
        graph (cmp/dependency-graph system component-keys)
        skeys (sort (dep/topo-comparator graph) component-keys)]
    (log/info "Update order" skeys)
    (reduce (fn [system key]
              (assoc system key
                     (-> (@#'cmp/get-component system key)
                         (@#'cmp/assoc-dependencies system)
                         (cond->
                             (contains? updated-keys key) (@#'cmp/try-action system key update-from [(get prev key)])
                             (contains? started-keys key) (@#'cmp/try-action system key cmp/start [])))))
            system skeys)))

(defn update-system-from
  ([system prev] (update-system-from system (keys system)
                                     prev   (keys prev)))
  ([system system-keys prev prev-keys]
   (let [sk (set system-keys)
         pk (set prev-keys)
         started (set/difference sk pk)
         stopped (set/difference pk sk)
         updated (set/intersection pk sk)]
     (log/info "Starting" started "; Stopping" stopped "; Updating" updated)
     (cmp/stop-system prev stopped)
     (update-system-from* system prev started updated))))

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
