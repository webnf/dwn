(ns webnf.nix.data
  (:require [clojure.java.io :as io]
            [clojure.string :as str]))

(defprotocol AsStr
  (as-str [o]))

(extend-protocol AsStr
  #?(:clj String :cljs js/String) (as-str [s] s)
  #?@(:clj [clojure.lang.Named (as-str [s]
                                       (assert (nil? (namespace s)))
                                       (name s))]) )

(defprotocol NixExpr
  (emit-expr [o]))

(defn emit-str [s]
  ["\""
   (str/replace s #"\"|\$"
                #(case %
                   "\"" "\\\""
                   "$" "\\$"))
   "\""])

(defn emit-key [k]
  (let [s (as-str k)]
    (if (re-matches #"(?:\p{Alpha}|[-_])+" s)
      [s] (emit-str s))))

(def ^:dynamic *indent* [])
(def ^:dynamic *pprint* true)

(defmacro fragment [frag]
  `(reify NixExpr
     (emit-expr [_]
       (doall ~frag))))

(defmacro inc-indent [& body]
  `(binding [*indent* (cons "  " *indent*)]
     (doall ~@body)))

(defn emit-ppstr [s]
  (if (or (not *pprint*) (re-find #"''" s))
    (emit-str s) ;; fallback
    (list* "''\n"
           (str/replace s #"\n" (inc-indent (apply str (concat *indent* ["\n"]))))
           (concat *indent* ["''"]))))

(defn ppstr [s]
  (fragment (emit-ppstr s)))

(defn emit-path [p]
  (str/replace (.getCanonicalPath (io/file p))
               #"[^a-zA-Z0-9/_\-.~]"
               (fn [s] (str "\\" s))))

(defn path [p]
  (fragment (emit-path p)))

(defn emit-nl []
  (when *pprint*
    (cons "\n" *indent*)))

(defn emit-map [m]
  (concat
   ["{"]
   (inc-indent
    (mapcat
     (fn [[k v]]
       (concat
        (emit-nl)
        (emit-key k)
        [" = "]
        (emit-expr v)
        [";"]))
     m))
   (emit-nl)
   ["}"]))

(defn emit-vec [v]
  (concat
   ["["]
   (apply concat (interpose [" "] (map emit-expr v)))
   ["]"]))

(defn emit-hvec [v]
  (if (empty? v)
    ["[]"]
    (concat
     ["["]
     (inc-indent
      (mapcat #(concat (emit-nl)
                       (emit-expr %))
              v))
     (emit-nl)
     ["]"])))

(defn emit-call [& exprs]
  (concat
   ["("]
   (apply concat (interpose [" "] (map emit-expr exprs)))
   [")"]))

(defn as-map [v]
  (fragment (emit-map v)))
(defn as-vec [v]
  (fragment (emit-vec v)))
(defn as-hvec [v]
  (fragment (emit-hvec v)))
(defn as-call [v]
  (fragment (emit-call v)))

#?(:clj (extend-protocol NixExpr
          clojure.lang.APersistentVector
          (emit-expr [v] (emit-vec v))
          clojure.lang.APersistentMap
          (emit-expr [m] (emit-map m))
          clojure.lang.ASeq
          (emit-expr [s] (apply emit-call s))
          #_clojure.lang.APersistentSet
          #_(emit-expr [s] (emit-map {:type "HashSet"
                                      :entries (as-vec s)}))
          String
          (emit-expr [s] (emit-str s))
          Number
          (emit-expr [n]
            [(str (bigdec n))])
          Boolean
          (emit-expr [b] [(str b)])
          nil
          (emit-expr [_] ["null"])))

(defn eprn [ss]
  (println (apply str ss)))

(defn nixprn [e]
  (eprn (emit-expr e)))

(defn render [expr]
  (apply str (emit-expr expr)))
