(ns webnf.dwn.container
  (:require
   ;; [dynapath.util :refer [addable-classpath? add-classpath-url]]
   [clojure.spec :as s]
   [clojure.tools.logging :as log]
   [clojure.java.io :refer [as-url]]
   [com.stuartsierra.component :as cmp]
   [webnf.dwn.util :refer [config-ref pass-or-require]]
   [webnf.dwn.system :as wds]
   [webnf.jvm :as jvm :refer [eval-in-container]]
   (webnf.jvm
    [security :as wjs :refer [with-security-manager blacklist-security-manager whitelist-security-manager to-permissions activate-system-security!]]
    [classloader :as wjc :refer [eval-in* package-forwarding-loader invoke overlay-classloader]]
    [threading :as wjt :refer [thread-group]])
   [clojure.java.io :as io]
   [clojure.string :as str])
  (:import (java.net URL URLClassLoader)
           (java.security AccessControlException)))

(try (activate-system-security!)
     (catch AccessControlException e
       (log/warn "Security already in place" (str e))))

(defn url-classloader [urls parent]
  (URLClassLoader. (into-array URL urls) (:class-loader parent)))

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

(defrecord Container [name classpath parent class-loader security-manager thread-group]
  cmp/Lifecycle
  (start [this]
    (if class-loader
      this
      (assoc this :class-loader
             (url-classloader (mapcat :urls classpath) parent))))
  (stop [this]
    (if class-loader
      (do (jvm/kill-container! this)
          (assoc this :class-loader nil))
      this))
  wds/Updateable
  (-get-key [this] ::container)
  (-update-from [this {p' :parent c' :classpath s' :security-manager t' :thread-group :as prev}]
    (if (and (identical? parent p')
             (identical? security-manager s')
             ;; FIXME use superset / semver check + .addURL
             (= classpath c'))
      (assoc this :class-loader (:class-loader prev))
      (do (cmp/stop prev)
          (cmp/start this)))))

(s/def ::container
  (s/keys :req-un [::classpath]
          :opt-un [::name ::parent ::security-manager ::thread-group]))

(s/def ::name string?)
(s/def ::classpath
  (s/coll-of ::classpath-entry))
(s/def ::classpath-entry
  (s/or :source-dirs (s/keys :req-un [:webnf.jvm.maven/name ::version ::source-dirs])
        :jar-file    (s/keys :req-un [:webnf.jvm.maven/name ::version ::jar-file])))
(s/def :webnf.jvm.maven/name qualified-symbol?)
(s/def ::version string?)
(s/def ::source-dirs (s/coll-of string?))
(s/def ::jar-file string?)
(s/def ::parent (config-ref ::jvm/class-loader))
(s/def ::security-manager (config-ref ::jvm/security-manager))
(s/def ::thread-group (config-ref ::jvm/thread-group))

(defn dir-url [path]
  (when-not (.isDirectory (io/file path))
    (log/warn "Classpath directory" path "not found"))
  (io/as-url (str "file:" path (when-not (str/ends-with? path "/") "/"))))

(defn jar-url [path]
  (when-not (.isFile (io/file path))
    (log/warn "Classpath jar" path "not found"))
  (io/as-url (str "file:" path)))

(defn classpath-entry [[type {:keys [name version source-dirs jar-file] :as cfg}]]
  (assoc cfg :urls
         (case type
           :source-dirs (map dir-url source-dirs)
           :jar-file [(jar-url jar-file)])))

(defn container [cfg]
  (let [{:keys [name classpath parent security-manager thread-group]
         :or {name (gensym "container-")
              parent [:inst {:class-loader base-loader}]
              security-manager [:inst default-security-manager]
              thread-group [:inst (wjt/thread-group (str (gensym (str name "-tg-")))
                                                    wjt/logging-ueh)]}
         :as res}
        (s/conform ::container cfg)]
    (if (s/invalid? res)
      (throw (ex-info "Invalid container config" (s/explain-data ::container cfg)))
      (let [[p' m'] (pass-or-require parent :parent)
            [sm' m''] (pass-or-require  security-manager :security-manager)
            [tg' m'''] (pass-or-require thread-group :thread-group)]
        (Container. name (map classpath-entry classpath)
                    p' nil sm' tg'
                    {::cmp/dependencies (into {} (concat m' m'' m'''))}
                    nil)))))
