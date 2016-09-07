(ns webnf.jvm
  (:require
   (webnf.jvm
    [threading :refer [run-on-group]]
    [security :refer [with-security-manager]]
    [classloader :refer [clj-read-evaluator eval-in*]])))

(defrecord Container [name class-loader security-manager thread-group])

(defn run-in-container [{:keys [thread-group security-manager class-loader]} ^Callable runnable]
  (run-on-group thread-group
                #(with-security-manager security-manager
                   (.call runnable))
                class-loader))

(defn eval-in-container [{:as cnt :keys [class-loader]}
                         form & curried-args]
  (run-in-container cnt #(eval-in* class-loader form curried-args)))
