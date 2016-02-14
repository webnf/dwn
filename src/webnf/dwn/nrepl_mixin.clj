(ns webnf.dwn.nrepl-mixin
  (:require
   [clojure.java.io :as io]
   [clojure.edn :as edn]
   [webnf.jvm :refer [eval-in-container]]
   (webnf.dwn [util :refer [dwn-read]]
              [component :refer [container-component -stop]]
              [container :refer [mixin]])))

(def nrepl-cfg
  (dwn-read
   (io/file #_"/home/herwig/src/webnf/dwn/result"
            (System/getProperty
             "dwn.runner.dir")
            "share/dwn/nrepl.edn")))

(defn nrepl-cmp [name classloader port start]
  (container-component
   name (:constructor nrepl-cfg)
   (mixin (str name "-container") (:classpath nrepl-cfg) classloader)
   {:host "localhost" :port port}
   start))

(defn start-nrepl [state state-key name port]
  (if-let [container (get-in state [state-key name])]
    (assoc-in state [state-key name :nrepl]
              (nrepl-cmp (str name "-nrepl") (:class-loader container)
                         port true))
    (throw (ex-info "Unknown component/plugin" {:key state-key
                                                :name name}))))

(defn stop-nrepl [state state-key name]
  (if-let [cmp (get-in state [state-key name :nrepl])]
    (do (-stop cmp)
        (update-in state [state-key name] dissoc :nrepl))
    (throw (ex-info "Unknown component/plugin, or no nrepl"
                    {:key state-key
                     :name name}))))

(defn here-nrepl [state port]
  (assoc state :nrepl
         (nrepl-cmp "dwn-nrepl" (.getContextClassLoader (Thread/currentThread))
                    port true)))
