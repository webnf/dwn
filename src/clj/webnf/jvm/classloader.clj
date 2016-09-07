(ns webnf.jvm.classloader
  (:require [clojure.string :as str]
            [webnf.jvm.enumeration :refer [empty-enumeration seq-enumeration]]
            [clojure.tools.logging :as log])
  (:import (java.net URL URLClassLoader)
           (webnf.jvm.classloader IClassLoader CustomClassLoader)))

(defn filtering-classloader
  "Filters access to its parent class loader by predicates.
   load-class? decides whether a class name is loaded by the parent
   load-resource? decides whether a resource name is loaded by the parent

   This does not conform to java's classloader model (which says that classes from the parent should take precedence), but it is useful to selectively share classes (mainly interfaces) between classloader worlds,
   e.g. Servlet containers share the javax.servlet package between applications, so that the server can directly invoke its methods on objects from the application ClassLoader."
  [^ClassLoader parent load-class? load-resource?]
  (CustomClassLoader.
   (reify IClassLoader
     (findClass [_ name]
       (if (load-class? name)
         (.loadClass parent name)
         (throw (ClassNotFoundException. (str "Could not load class" name)))))
     (findResources [_ name]
       (if (load-resource? name)
         (.getResources parent name)
         empty-enumeration)))))

(defn overlay-classloader
  "Overlays classes over existing classes in parent"
  [^ClassLoader parent class-overlay resource-overlay]
  (CustomClassLoader.
   (reify IClassLoader
     (findClass [_ name]
       (or (get class-overlay name) (.loadClass parent name)))
     (findResources [_ name]
       (or (get resource-overlay name) (.getResources parent name))))))

(comment
  ;; version compiles to a series of else ifs and .startsWith's
  (defmacro prefix? [name & pfs]
    `(or ~@(for [pf pfs] `(.startsWith ^String ~name ~pf))))

  ;; unused
  (defmacro <-
    "Start a -> chain in an ->> chain"
    [& arms]
    `(-> ~(last arms) ~@(butlast arms))))

(import java.util.regex.Pattern)

(defn prefix-regex [pfs]
  (->> (map #(str "(?:" (Pattern/quote %) ".*)") pfs)
       (str/join "|")
       re-pattern))

;; compiles to a regex match
(defmacro prefix? [name & pfs]
  `(re-matches
    ~(prefix-regex pfs)
    ~name))

(defn prefix-pred [prefixes]
  (if-let [re (and (seq prefixes)
                   (prefix-regex prefixes))]
    #(re-matches re %)
    (constantly false)))

(defn package-forwarding-loader
  "Create a filtering-classloader, which forwards a set of prefixes"
  [parent-classloader
   forwarded-classname-prefixes
   forwarded-resname-prefixes]
  (filtering-classloader
   parent-classloader
   (prefix-pred forwarded-classname-prefixes)
   (prefix-pred forwarded-resname-prefixes)))

;; Reflection - based FFI

(def weak-memoize memoize) ;; FIXME

(defn as-name [n]
  (cond
    (string? n) n
    (instance? clojure.lang.Named n) (name n)
    (instance? Class n) (.getName ^Class n)
    :else (throw (ex-info "Not Named" {:named n}))))

(defn ^Class load-class [^ClassLoader cl class-name]
  (.loadClass cl (as-name class-name)))

(defn ^java.lang.reflect.Method method-object [cl class-method signature]
  (let [cn (namespace class-method)
        mn (name class-method)]
    (.getMethod (load-class cl cn) mn
                (into-array Class (map (comp (partial load-class cl)
                                             as-name)
                                       signature)))))

(defn method [cl class-method signature]
  (let [m (method-object cl class-method signature)]
    #(.invoke m %1 (into-array Object %&))))

(defn static-method [cl class-method signature]
  (let [cls (load-class cl (namespace class-method))
        m (method-object cl class-method signature)]
    #(.invoke m cls (into-array Object %&))))

(def ^:private invoke-method
  (weak-memoize
   (fn [cl cnt]
     (method cl 'clojure.lang.IFn/invoke (repeat cnt Object)))))

(defn invoke [clj-fn args]
  (let [res (apply (invoke-method (.getClassLoader
                                   (class clj-fn))
                                  (count args))
                   clj-fn
                   args)]
    ;; (log/debug clj-fn args " =>" res)
    res))

(def clj-read-evaluator
  (weak-memoize
   (fn [cl]
     (let [read-string' (static-method cl :clojure.lang.RT/readString [String])
           eval' (static-method cl :clojure.lang.Compiler/eval [Object])]
       (fn [form-str]
         (let [res (eval' (read-string' form-str))]
           ;; (log/debug form-str "=>" res)
           res))))))

(defmacro with-context-classloader [cl & body]
  `(let [t# (Thread/currentThread)
         cl# (.getContextClassLoader t#)]
     (try (.setContextClassLoader t# ~cl)
          ~@body
          (finally
            (.setContextClassLoader t# cl#)))))

(defn eval-in*
  ([cl form] (eval-in* cl form []))
  ([cl form curried-args]
   (let [in (pr-str form)
         reval (clj-read-evaluator cl)]
     (if (seq curried-args)
       (with-context-classloader cl
         (reduce #(invoke %1 [%2])
                 (reval in) curried-args))
       (with-context-classloader cl
         (reval in))))))
