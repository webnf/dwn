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
   (sun.misc Signal SignalHandler)
   (com.etsy.net JUDS UnixDomainSocketServer)))

(defonce system
  (agent (cmp/system-map)
         :error-handler (fn [a e]
                          (.println System/err "System error")
                          ;; (.printStackTrace e)
                          (log/error e "System error"))))

(defn run-component! [sys component-key input-stream output-stream component]
  (with-open [ir (io/reader input-stram)
              ow (io/writer output-stream)]
    (if (contains? sys component-key)
      (do (println "ERROR component-key:" component-key "already used. Please stop it before deploying this.")
          sys)
      (binding [*out* ow *in* ir]))))

(defn update! [in-stream out-stream]
  (let [cfg (config-read in-stream)]
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
