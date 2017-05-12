(ns webnf.dwn.component
  (:require [clojure.spec.alpha :as s]
            [com.stuartsierra.component :as cmp]
            [webnf.jvm :refer [eval-in-container]]
            [webnf.dwn.container :as wdc :refer [container]]
            [clojure.tools.logging :as log]
            [webnf.dwn.util :refer [require-call-form config-ref guard-config!]]))

(s/def ::factory qualified-symbol?)
(s/def ::config any?)
(s/def ::container (config-ref ::wdc/container))

(s/def ::container-component
  (s/keys :req-un [::factory ::config ::container]
          :opt-un [::name]))

(defrecord ContainerComponent [name factory config container component]
  cmp/Lifecycle
  (start [this]
    (log/info "Starting Component" name factory "with config" config "on container" (:name container))
    (if component
      this
      (assoc this :component
             @(eval-in-container
               container
               (require-call-form factory config false
                                  (partial list `cmp/start))))))
  (stop [this]
    (log/info "Stopping Component" name factory)
    (if component
      (assoc this :component
             (do @(eval-in-container
                   container 'com.stuartsierra.component/stop
                   component)
                 nil))
      this)))

(defn container-component [name component-sym container config start]
  (->ContainerComponent
   false container
   @(eval-in-container
     container
     (require-call-form component-sym config false
                        (if start
                          #(list 'com.stuartsierra.component/start %)
                          identity)))))

(defn container-component [{:keys [name factory config container]
                            :or {name (gensym "component-")}
                            :as cfg}]
  (guard-config! ::container-component cfg "Invalid Container Config")
  (let [[container' meta'] (if (keyword? container)
                             [nil {::cmp/dependencies {:container container}}]
                             [container nil])]
   (ContainerComponent. name factory config container' nil meta' nil)))

(defrecord LauncherComponent [main args container])

(defn launcher-component [{:keys [container main args]}]
  (let [[container' meta'] (if (keyword? container)
                             [nil {::cmp/dependencies {:container container}}]
                             [container nil])]
    (LauncherComponent. main args container' meta' nil)))
