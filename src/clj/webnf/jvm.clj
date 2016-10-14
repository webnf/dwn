(ns webnf.jvm
  (:require
   [clojure.spec :as s]
   (webnf.jvm
    [threading :refer [run-on-group]]
    [security :refer [with-security-manager]]
    [classloader :refer [clj-read-evaluator eval-in*]])
   [clojure.tools.logging :as log]))

(defn security-manager? [o]
  (instance? SecurityManager o))

(defn thread-group? [o]
  (instance? ThreadGroup o))

(defn class-loader? [o]
  (instance? ClassLoader o))

(s/def ::class-loader class-loader?)
(s/def ::security-manager security-manager?)
(s/def ::thread-group thread-group?)

(s/def ::container
  (s/keys :req-un [::class-loader ::security-manager ::thread-group]))

(defn run-in-container [{:keys [name thread-group security-manager class-loader]} ^Callable runnable]
  (log/trace "run-in-container" name thread-group security-manager class-loader runnable)
  (run-on-group thread-group
                #(with-security-manager security-manager
                   (.call runnable))
                class-loader))

(defn eval-in-container [{:as cnt :keys [name class-loader]}
                         form & curried-args]
  (log/trace "eval-in-container" name form curried-args)
  (run-in-container cnt #(eval-in* class-loader form curried-args)))

(defn kill-container! [container]
  ;; FIXME TODO
  (print "TBD"))
