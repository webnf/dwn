(ns webnf.dwn.container
  (:require
   ;[dynapath.util :refer [addable-classpath? add-classpath-url]]
   [clojure.tools.logging :as log]
   [clojure.java.io :refer [as-url]]
   [webnf.jvm :refer [eval-in-container ->Container]]
   (webnf.jvm
    [security :refer [with-security-manager blacklist-security-manager whitelist-security-manager to-permissions activate-system-security!]]
    [classloader :refer [eval-in* package-forwarding-loader invoke overlay-classloader]]
    [threading :refer [thread-group]]))
  (:import (java.net URL URLClassLoader)
           (java.security AccessControlException)))

(try (activate-system-security!)
     (catch AccessControlException e
       (log/warn "Security already in place" (str e))))

(defn url-classloader [urls parent]
  (URLClassLoader. (into-array URL (map as-url urls)) parent))

(def app-loader (.getClassLoader clojure.lang.RT))

(def base-loader (package-forwarding-loader
                  app-loader
                  #{"java." "javax." "org.slf4j." "com.sun."
                    "org.apache.commons.logging." "org.apache.log4j."
                    "ch.qos.logback."}
                  nil))

(def default-security-manager
  (blacklist-security-manager (to-permissions
                               ["setSecurityManager"
                                "exitVM"])))

(defn container [name classpath & [security-manager thread-group]]
  (->Container
   name
   (url-classloader classpath base-loader)
   (or security-manager default-security-manager)
   (or thread-group (ThreadGroup. name))))

(defn mixin [name classpath parent-loader & [security-manager thread-group]]
  #_(assert (addable-classpath? parent-loader))
  #_(doseq [url (map as-url classpath)]
      (add-classpath-url parent-loader url))
  (->Container
   name
   (url-classloader classpath parent-loader)
   (or security-manager default-security-manager)
   (or thread-group (ThreadGroup. name))))

(defn clj-container [name classpath & [security-manager thread-group]]
  (mixin name classpath app-loader security-manager thread-group))
