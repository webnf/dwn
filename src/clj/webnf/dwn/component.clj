(ns webnf.dwn.component
  (:require [webnf.jvm :refer [eval-in-container]]
            [webnf.dwn.container :refer [container clj-container]]
            [clojure.tools.logging :as log]
            [webnf.dwn.util :refer [require-call-form]]))

(defprotocol Stopped
  (-start [_]))
(defprotocol Started
  (-stop [_]))
(defprotocol Stateful
  (-dump [_])
  (-restore [_ dump]))

(defrecord ContainerComponent [started container component]
  Stopped
  (-start [cmp] (if started
                  cmp
                  (assoc cmp
                         :started true
                         :component
                         @(eval-in-container
                           container
                           'com.stuartsierra.component/start
                           component))))
  Started
  (-stop [cmp] (if started
                 (assoc cmp
                        :started false
                        :component @(eval-in-container
                                     container
                                     'com.stuartsierra.component/stop
                                     component))
                 cmp)))

(defn container-component [name component-sym container config start]
  (->ContainerComponent
   false container
   @(eval-in-container
     container
     (require-call-form component-sym config false
                        (if start
                          #(list 'com.stuartsierra.component/start %)
                          identity)))))

