(ns webnf.dwn.deps.aether
  (:import
   java.nio.file.Files
   java.nio.file.attribute.FileAttribute
   java.io.PushbackReader)
  (:require [webnf.dwn.deps.aether.cons :as cons]
            ;; [webnf.nix.data :as data]
            [clojure.pprint :refer [pprint]]
            [clojure.java.io :as io]
            [clojure.edn :as edn]))

(def default-repositories
  {"central" "http://repo1.maven.org/maven2"
   "clojars" "https://clojars.org/repo"})

(defn temp-local-repo []
  (-> (Files/createTempDirectory "m2-" (into-array FileAttribute []))
      .toFile (doto .deleteOnExit)
      cons/local-repository))

(defn memoize-singular [f]
  (let [memo (atom {})]
    (fn [& args]
      (if-let [v (get @memo args)]
        @v
        @(get (swap! memo (fn [m]
                            (let [prev-delay (get m args)]
                              (if (nil? prev-delay)
                                (assoc m args (delay (apply f args)))
                                m))))
              args)))))

(defn- art-key [art]
  [(.getGroupId art)
   (.getArtifactId art)
   (.getVersion art)
   (.getClassifier art)])

(defn coordinate* [art]
  [(.getGroupId art)
   (.getArtifactId art)
   (.getVersion art)])

(defn get-dependencies [desc done {:keys [include-optionals include-scopes]}]
  (->> (cond-> (.getDependencies desc)
         (not include-optionals) (->> (remove #(.isOptional %))))
       (filter #(contains? include-scopes (.getScope %)))
       (remove #(contains? done (art-key (.getArtifact %))))))

(defn download-info [arti {:as config}]
  (let [art (cons/artifact arti)
        rv (.getVersion (or (cons/version-resolution art config)
                            art))
        rart (cons/artifact [(keyword (.getGroupId art)
                                      (.getArtifactId art))
                             rv])
        desc (cons/artifact-descriptor rart config)]

    (if-let [layout (try (cons/repository-layout (.getRepository desc) config)
                         (catch Exception e
                           (println "ERROR" "no download info" (art-key rart) (.getRepository desc))))]
      (let [base (.. desc getRepository getUrl)
            loc (.getLocation layout rart false)
            cs-loc (some #(when (= "SHA-1" (.getAlgorithm %))
                            (.getLocation %))
                         (.getChecksums layout rart false loc))]
        {:art art
         :desc desc
         :location loc
         :cs-location cs-loc
         :base base
         :coord (coordinate* art)
         :deps (mapv #(coordinate* (.getArtifact %))
                     (get-dependencies desc #{} config))
         :sha1 (try (slurp (str base "/" cs-loc))
                    (catch Exception e
                      (println "ERROR" "couldn't fetch sha-1" base cs-loc)
                      nil))
         :snapshot (.isSnapshot art)
         :resolved-version rv})
      {:desc desc :art art})))

(defn expand-download-info
  ([art conf] (expand-download-info art conf #{}))
  ([art {:keys [m-dl-info] :as conf} done]
   (lazy-seq
    (let [{:keys [desc] :as res} (m-dl-info art)
          sub-deps (get-dependencies desc done conf)
          done' (into done (cons (art-key (.getArtifact desc))
                                 (map #(art-key (.getArtifact %)) sub-deps)))

          thunks (mapv #(future
                          (let [di (expand-download-info
                                    (.getArtifact %) conf
                                    (disj done' (art-key (.getArtifact %))))]
                            (lazy-seq (cons (assoc (first di) :scope (.getScope %))
                                            (next di)))))
                       sub-deps)]
      (cons res (mapcat deref thunks))))))

(defn expand-download-infos
  ([coordinates conf] (mapcat #(expand-download-info % conf) coordinates)))

(defn repo-for [coordinates conf]
  (let [download-infos (expand-download-infos (map cons/nix-artifact coordinates)
                                              conf)]
    (reduce (fn [res {:as dli :keys [art desc]}]
              (assoc-in res (coordinate* art)
                        (assoc (select-keys dli [:resolved-version :sha1])
                               :dependencies (mapv #(coordinate* (.getArtifact %))
                                                   (get-dependencies desc #{} conf)))))
            {} download-infos)))

(defn merge-aether-config [prev-config & {:as next-config}]
  (let [{:keys [system session local-repo offline transfer-listener
                mirror-selector repositories include-optionals include-scopes]
         :as config}
        (merge prev-config next-config)]
    (-> {:system (or system @cons/default-repo-system)
         :local-repo (or local-repo (temp-local-repo))
         :offline (boolean offline)
         :include-optionals (if (contains? config :include-optionals)
                              (boolean include-optionals)
                              true)
         :include-scopes (or include-scopes #{"compile" "runtime" "provided" "system" "test"})}
        (as-> config
            (assoc config :session (or session (cons/session config)))
            (assoc config :repositories (cons/repositories (or repositories default-repositories) config))

            (assoc config :m-dl-info
                   (memoize-singular #(download-info % config)))))))

(defn aether-config [& {:keys [system session local-repo offline transfer-listener mirror-selector repositories] :as config}]
  (merge-aether-config config))

(defn -main [repo-out-file coordinates-str repos-str]
  (let [repo (repo-for (edn/read-string coordinates-str)
                       (aether-config :include-optionals false
                                      :include-scopes #{"compile"}
                                      :repositories
                                      (into {}
                                            (for [r (edn/read-string repos-str)]
                                              [(str (gensym "repo")) r]))))]
    (with-open [o (io/writer repo-out-file)]
      (binding [*out* o]
        (pprint repo)))
    (shutdown-agents)
    (System/exit 0)))
