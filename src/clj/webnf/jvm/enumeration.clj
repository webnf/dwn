(ns webnf.jvm.enumeration
  (:import java.util.Enumeration))

(def empty-enumeration
  "An enumeration with zero elements."
  (reify Enumeration
    (hasMoreElements [_] false)
    (nextElement [_] (throw (IllegalStateException. "No more elements")))))

(defn seq-enumeration
  "The missing counterpart to enumeration-seq"
  [s]
  (if (seq s)
    (let [the-seq (volatile! s)]
      (reify Enumeration
        (hasMoreElements [_]
          (boolean (seq @the-seq)))
        (nextElement [this]
          (let [s (seq @the-seq)]
            (assert s)
            (vswap! the-seq next)
            (first s)))))
    empty-enumeration))
