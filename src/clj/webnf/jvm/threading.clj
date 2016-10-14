(ns webnf.jvm.threading
  (:require [clojure.tools.logging :as log])
  (:import java.util.concurrent.FutureTask))

(def logging-ueh
  "The default UncaughtExceptionHandler, which logs exceptions to clojure.tools.logging/error"
  (reify Thread$UncaughtExceptionHandler
    (uncaughtException [_ thread throwable]
      (.printStackTrace throwable)
      (log/error throwable "Uncaught Exception in thread" thread))))

(defn thread-group
  "A thread group with a configurable default UncaughtExceptionHandler"
  ([] (thread-group logging-ueh))
  ([ueh] (thread-group (name (gensym "thread-group-")) ueh))
  ([name ueh] (thread-group (.getThreadGroup (Thread/currentThread))
                            name ueh))
  ([parent name ueh]
   (webnf.jvm.threading.ThreadGroup. parent name ueh)))

(defn run-on-group
  ([group ^Callable callable context-cl]
   (let [p (FutureTask. #(try (callable)
                              ;; FutureTask blocks thread's default UEH
                              (catch Exception e
                                (.uncaughtException group (Thread/currentThread) e)
                                (throw e))))
         t (Thread. ^ThreadGroup group p)]
     (.setContextClassLoader t context-cl)
     (.start t)
     p)))
