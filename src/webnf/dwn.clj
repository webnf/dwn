(ns webnf.dwn
  (:require [clojure.java.io :as io]
            [clojure.string :as str]
            [clojure.tools.logging :as log]
            [clojure.edn :as edn]
            [clojure.pprint :refer [pprint]]
            [webnf.jvm :refer [eval-in-container]]
            (webnf.dwn
             [util :refer [read-cp dwn-read]]
             [component :refer [container-component -start -stop]]
             [container :refer [clj-container container]]
             [plugin :refer [init-plugin run-plugin-cmd]]
             [nrepl-mixin :refer [start-nrepl here-nrepl stop-nrepl]]))
  (:import (java.net InetSocketAddress)
           (java.io PushbackReader OutputStream)
           (java.nio.channels Channels ServerSocketChannel)))

(declare run-command*)
(defn spurt [^OutputStream os s]
  (.write os (.getBytes s))
  (.write os (.getBytes "\n")))

(def commands
  {:do (fn [state os & cmds]
         (reduce #(run-command* %1 %2 os) state cmds))
   :echo (fn [state os & args]
           (do (spurt os (str (str/join " " (map pr-str args)) \newline))
               state))
   :shutdown (fn [state os]
               (do (spurt os ";; shutting down\n")
                   (assoc state :accepting false)))
   :pr-state (fn [state os & keys]
               (do (spurt os (pr-str (get-in state keys)))
                   state))
   :load-component (fn [state os name component-sym config urls]
                     (when-let [cmp (get-in state [:components name])]
                       (throw (ex-info "Component loaded" {:name name})))
                     (let [state* (assoc-in state [:components name]
                                            (container-component
                                             name component-sym
                                             (container name urls)
                                             config false))]
                       (spurt os (pr-str [:loaded name]))
                       state*))
   :load-plugin (fn [state os name component-sym config urls]
                  (when-let [cmp (get-in state [:plugins name])]
                    (throw (ex-info "Plugin loaded" {:name name})))
                  (let [state* (assoc-in state [:plugins name]
                                         (init-plugin name component-sym config urls))]
                    (spurt os (pr-str [:loaded-plugin name]))
                    state*))
   :unload-component (fn [state os name]
                       (let [res (update state :components dissoc name)]
                         (spurt os (pr-str [:unloaded name]))
                         res))
   :start-component (fn [state os name]
                      (let [state* (update-in state [:components name] -start)]
                        (spurt os (pr-str [:started name]))
                        state*))
   :stop-component (fn [state os name]
                     (let [state* (update-in state [:components name] -stop)]
                       (spurt os (pr-str [:stopped name]))
                       state*))
   :plugin-cmd (fn [state os name & cmd]
                 (if-let [plg (get-in state [:plugins name])]
                   (assoc-in state [:plugins name]
                             (apply run-plugin-cmd os plg cmd))
                   (spurt os (pr-str [:error "No plugin" name]))))
   :nrepl (fn [state os port]
            (here-nrepl state port))
   :component-nrepl (fn [state os name port]
                      (start-nrepl state :components name port))
   :plugin-nrepl (fn [state os name port]
                   (start-nrepl state :plugins name port))
   :stop-plugin-nrepl (fn [state os name]
                        (stop-nrepl state :plugins name))})

(defn short-print [o]
  (binding [*print-level* 1 *print-length* 8]
    (with-out-str (pprint o))))

(defn run-command* [state command os]
  (if-let [cmd (and (vector? command)
                    (keyword? (first command))
                    (get commands (first command)))]
    (try
      (log/debug "Running" (first command) (map short-print (next command)))
      (update (apply cmd state os (next command))
              :command-history conj [(dissoc state :command-history) command])
      (catch Exception e
        (pprint e)
        (binding [*out* (java.io.PrintWriter. (io/writer os))]
          (prn [:exception (str (class e)) (.getMessage e) (ex-data e)])
          (println "\nBacktrace:\n")
          (pprint e))
        (reduced state))
      (finally
        (.flush os)))
    (do (spurt os (pr-str [:error "Not a command" command]))
        (reduced state))))

(defn run-command [state command output-chan]
  (let [bos (java.io.ByteArrayOutputStream.)
        res (run-command* state command bos)]
    (with-open [os (Channels/newOutputStream output-chan)]
      (.write os (.toByteArray bos)))
    (if (reduced? res)
      @res res)))

(defn call-command! [state-agent command]
  (with-open [os (java.io.ByteArrayOutputStream.)]
    (await (send state-agent run-command* command os))
    (String. (.toByteArray os) "UTF-8")))

(defonce current-state (agent {:accepting true :command-history []}))

(defn read-command [^ServerSocketChannel ssc]
  (let [cc (.accept ssc)
        is (Channels/newInputStream cc)]
    (when-let [command (try (dwn-read is)
                            (catch Exception e
                              (log/error e "When reading command")
                              (with-open [os (Channels/newOutputStream cc)]
                                (spurt os (pr-str [:read-error (.getMessage e)])))
                              nil))]
      [command cc])))

(defn cmd-loop [state-agent ssc]
  (when (:accepting @state-agent)
    (log/debug "Waiting for command")
    (if-let [[cmd cc] (read-command ssc)]
      (do (log/debug "Source command" cmd)
          (with-open [cc cc]
            (await (send state-agent run-command cmd cc))))
      (log/error "No command read"))
    (recur state-agent ssc)))

(defn -main [host port]
  (println "DWN called with" (mapv pr-str [host port]))

  (let [ssc (doto (ServerSocketChannel/open)
              (.bind (InetSocketAddress. host (Long/parseLong port))))]
    (cmd-loop current-state ssc)))

