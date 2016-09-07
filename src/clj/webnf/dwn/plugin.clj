(ns webnf.dwn.plugin
  (:require
   [clojure.pprint :refer [pprint]]
   [clojure.tools.logging :as log]
   [webnf.dwn.util :refer [require-call-form read-cp]]
   [webnf.jvm :refer [eval-in-container run-in-container]]
   [webnf.dwn.container :refer [clj-container]])
  (:import (java.io OutputStreamWriter)))

(defn init-plugin [name plugin-sym config urls]
  (let [container (clj-container name urls)
        config' @(eval-in-container
                  container
                  (require-call-form plugin-sym config false))]
    (assoc container
           ::name   name
           ::state  (:init-state config')
           ::config config'
           ::command-runner @(eval-in-container
                              container `(fn [run#]
                                           (fn [state# cmd# args# io#]
                                             (run# (apply cmd# args#) state# io#)))
                              (:runner config')))))

(defn- rpc [io plugin cmd args]
  (let [{{{cmd' cmd} :commands} ::config
         :keys [::command-runner ::state]}   plugin]
    (println cmd cmd' command-runner
             (count args) (map class args))
    @(run-in-container
      plugin
      #(update plugin ::state command-runner
               cmd' args
               (assoc io :fail
                      (fn [garbage-state]
                        (log/warn "Discarding failed state" garbage-state
                                  "; rolling back to" state)
                        state))))))

(defn run-plugin-cmd [os plugin cmd & args]
  (rpc {:output-stream os
        :writer (OutputStreamWriter. os)}
       plugin cmd args))

(defn rpc-test [plugin cmd & args]
  (rpc {:writer *out*} plugin cmd args))

