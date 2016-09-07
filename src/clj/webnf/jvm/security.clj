(ns webnf.jvm.security
  "Tools for running code with restricted runtime permissions.

  Call activate-system-security! to let this namespace take runtime-wide control via (System/setSecurityManager _)
  Then use the with-security-manager with an implementation of webnf.jvm.security.ISecurityManager (constructors provided here), to run code in a security-restricted and/or -monitored context.

  The current ISecurityManager instance is stored in an InheritedThreadLocal.
  TODO: Implement a RuntimePermission to restrict setting that InheritedThreadLocal"
  (:require [clojure.tools.logging :as log])
  (:import webnf.jvm.security.ISecurityManager
           (java.security Permissions Permission AccessControlException)))

(def nil-security-manager
  (reify ISecurityManager
    (getThreadGroup [_] (.getThreadGroup (Thread/currentThread)))
    (checkPermission [_ perm]
      nil)))

(defonce ^:private security-manager
  (webnf.jvm.security.SecurityManager. nil-security-manager))

(defn activate-system-security! []
  (when-let [sm (System/getSecurityManager)]
    (when (not= sm security-manager)
      (throw (ex-info "There is a security manager already in place"
                      {:current-sm sm}))))
  (log/debug "Activating system-wide webnf SecurityManager")
  (System/setSecurityManager security-manager))

(defmacro with-security-manager [ism & body]
  `(let [^webnf.jvm.security.SecurityManager
         sm# @~#'security-manager
         ^ThreadLocal
         ism-var# (.-ism_var sm#)
         prev# (.get ism-var#)]
     (assert (= sm# (System/getSecurityManager))
             "Webnf SecurityManager not activated")
     (try
       (.set ism-var# ~ism)
       ~@body
       (finally (.set ism-var# prev#)))))

(defn whitelist-security-manager [^Permissions allowed]
  (reify ISecurityManager
    (getThreadGroup [_] (.getThreadGroup (Thread/currentThread)))
    (checkPermission [_ perm]
      (when-not (.implies allowed perm)
        (throw (AccessControlException. "Permission not whitelisted" perm))))))

(defn blacklist-security-manager [^Permissions forbidden]
  (reify ISecurityManager
    (getThreadGroup [_] (.getThreadGroup (Thread/currentThread)))
    (checkPermission [_ perm]
      (when (.implies forbidden perm)
        (throw (AccessControlException. "Permission blacklisted" perm))))))

(defn audit-security-manager [notify-permission!]
  (reify ISecurityManager
    (getThreadGroup [_] (.getThreadGroup (Thread/currentThread)))
    (checkPermission [_ perm]
      (notify-permission! perm))))

(defn to-permission [perm]
  (if (string? perm)
    (RuntimePermission. perm)
    (do (assert (instance? Permission perm) "Not a permission")
        perm)))

(defn to-permissions [perm-coll]
  (reduce (fn [^Permissions perms perm]
            (.add perms (to-permission perm))
            perms)
          (Permissions.)
          perm-coll))
