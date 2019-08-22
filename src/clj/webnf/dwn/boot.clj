(ns webnf.dwn.boot
  (:require
   [clojure.pprint :refer [pprint]]
   [clojure.tools.logging :as log]
   [clojure.java.io :as io]
   [webnf.jvm :refer [eval-in-container]]
   (webnf.dwn [config :as config]
              [system :refer [update-from]])
   [com.stuartsierra.component :as cmp])
  (:import
   (sun.misc Signal SignalHandler)
   (com.etsy.net JUDS UnixDomainSocketServer)))

(declare system)

(defn update! [in-stream out-stream]
  (let [cfg (config/read (config/reader in-stream))]
    (log/info "Updating config\n"
              (with-out-str (pprint cfg)))
    (binding [*out* (io/writer out-stream)]
      (send system #(update-from cfg %))
      (println "Updated!!!"))
    (log/info "Update complete!")))

(defn install-handler! [signal thunk]
  #_(log/error "SIG" signal "handler not implemented")
  (Signal/handle (Signal. (name signal))
                 (reify SignalHandler
                   (handle [_ sig] (thunk signal)))))

(defn -main [cfg-server]
  (let [server (.getAbsoluteFile (io/file cfg-server))]
    (when (.mkdirs (.getParentFile server))
      (log/info "Created socket directory" (.getParent server)))
    (when (.delete server)
      (log/warn "Unlinking previous socket"))
    (let [socket-server (UnixDomainSocketServer. cfg-server JUDS/SOCK_STREAM 1)
          tih (fn [_]
                (try
                  (log/info "SIG" :TERM "/" :INT "handler fired, shutting down")
                  (shutdown-agents)
                  (.unlink socket-server)
                  (catch Exception e
                    (log/error e "during shutdown")
                    (System/exit 1))
                  (finally (System/exit 0))))]
      (try
        (install-handler! :TERM tih)
        (install-handler! :INT tih)
        (log/info "Started up, waiting for config on" cfg-server)
        (loop []
          (with-open [sock (.accept socket-server)
                      is (.getInputStream sock)
                      os (.getOutputStream sock)]
            (try (update! is os)
                 (catch Exception e
                   (log/error e "During config read"))))
          (recur))
        (catch Exception e
          (log/fatal e "Unexpected exit, running shutdown routines"))
        (finally (tih nil))))))
