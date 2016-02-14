(ns webnf.dwn.nrepl
  (:require
   [clojure.tools.logging :as log]
   [com.stuartsierra.component :as cmp]
   [clojure.tools.nrepl.server :as nrepl]))

(def handler
  (try (require 'cider.nrepl)
       (eval 'cider.nrepl/cider-nrepl-handler)
       (catch Exception e
         (log/warn e "Falling back to plain nrepl")
         nil)))

(defn start-server [handler port]
  (apply nrepl/start-server
         (concat
          (when handler [:handler handler])
          (when port [:port port]))))

(defrecord Nrepl [port server]
  cmp/Lifecycle
  (start [this]
    (if server
      this
      (assoc this :server (start-server handler port))))
  (stop [this]
    (if server
      (do (nrepl/stop-server server)
          (assoc this :server nil))
      this)))

(defn nrepl [conf]
  (map->Nrepl conf))
