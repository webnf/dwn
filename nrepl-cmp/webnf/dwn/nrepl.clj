(ns webnf.dwn.nrepl
  (:require
   [clojure.edn :as edn]
   [clojure.spec.alpha :as s]
   [clojure.tools.logging :as log]
   [com.stuartsierra.component :as cmp]
   [nrepl.server :as nrepl]))

(defn start-server [host port middleware]
  (apply nrepl/start-server
         :handler (apply nrepl/default-handler middleware)
         (concat
          (when host [:bind host])
          (when port [:port port]))))

(defrecord Nrepl [server host port middleware]
  cmp/Lifecycle
  (start [this]
    (log/info "Starting nrepl on" host ":" port "with middleware" middleware)
    (if server
      this
      (assoc this :server (start-server host port middleware))))
  (stop [this]
    (log/info "Stopping nrepl on" host ":" port )
    (if server
      (do (nrepl/stop-server server)
          (assoc this :server nil))
      this)))

(s/def ::host string?)
(s/def ::port integer?)
(s/def ::middleware (s/coll-of ifn? :kind vector?))
(s/def ::enable-cider boolean?)

(s/def ::nrepl-config
  (s/keys :opt-un [::host ::port ::middleware ::enable-cider]))

(s/def ::nrepl (s/fspec))

(defn nrepl [conf]
  (log/info "Creating NREPL component" conf)
  (let [{:keys [enable-cider] :as c} (s/conform ::nrepl-config conf)]
    (if (= ::s/invalid c)
      (throw (ex-info "Invalid NREPL configuration" (s/explain-data ::nrepl-config conf)))
      (map->Nrepl
       (cond-> conf
         enable-cider (update :middleware
                              (fn [mv]
                                (require 'cider.nrepl)
                                (-> (mapv resolve (eval 'cider.nrepl/cider-middleware))
                                    (into mv)))))))))

(defn -main [conf]
  (cmp/start
   (nrepl (edn/read-string conf))))
