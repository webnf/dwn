(ns webnf.dwn.example.leiningen)

(defn -main [& args]
  (println "You said:" (pr-str args))
  (System/exit 0))
