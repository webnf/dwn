(ns webnf.dwn.boot
  (:require
   [clojure.pprint :refer [pprint]]
   [clojure.tools.logging :as log]
   [clojure.java.io :as io]
   [webnf.jvm :refer [eval-in-container]]
   (webnf.dwn [config :refer [config-read]]
              [system :refer [update-from]])
   [com.stuartsierra.component :as cmp])
  (:import
   (sun.misc Signal SignalHandler)))

(defonce system
  (agent (cmp/system-map)
         :error-handler (fn [a e]
                          (.println System/err "System error")
                          ;; (.printStackTrace e)
                          (log/error e "System error"))))

(defn update! [cfg-file]
  (let [cfg (config-read cfg-file)]
    (log/info "Updating config\n"
              (with-out-str (pprint cfg)))
    (send system #(update-from cfg %))))

(defn install-handler! [signal thunk]
  #_(log/error "SIG" signal "handler not implemented")
  (Signal/handle (Signal. (name signal))
                 (reify SignalHandler
                   (handle [_ sig] (thunk signal)))))

(defn -main [& [cfg-file :as args]]
  (update! cfg-file)
  (install-handler! :HUP (fn [_]
                           (log/info "SIG" :HUP "handler fired")
                           (update! cfg-file)))
  (let [tih (fn [_]
              (try
                (log/info "SIG" :TERM "/" :INT "handler fired, shutting down")
                (shutdown-agents)
                (catch Exception e
                  (log/error e "during shutdown")
                  (System/exit 1))
                (finally (System/exit 0))))]
    (install-handler! :TERM tih)
    (install-handler! :INT tih)))
