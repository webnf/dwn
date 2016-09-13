(ns webnf.dwn.nrepl
  (:require
   [clojure.spec :as s]
   [clojure.tools.logging :as log]
   [com.stuartsierra.component :as cmp]
   [clojure.tools.nrepl.server :as nrepl]))

(defn start-server [host port middleware]
  (apply nrepl/start-server
         :handler (apply nrepl/default-handler middleware)
         (concat
          (when host [:bind host])
          (when port [:port port]))))

(defrecord Nrepl [server host port middleware]
  cmp/Lifecycle
  (start [this]
    (if server
      this
      (assoc this :server (start-server host port middleware))))
  (stop [this]
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
  (let [{:keys [enable-cider] :as c} (s/conform ::nrepl-config conf)]
    (if (= ::s/invalid c)
      (throw (ex-info "Invalid NREPL configuration" (s/explain-data ::nrepl-config conf)))
      (map->Nrepl
       (cond-> c
         enable-cider (update :middleware
                              (fn [mv]
                                (require 'cider.nrepl)
                                (-> (mapv resolve (eval 'cider.nrepl/cider-middleware))
                                    (into mv)))))))))
