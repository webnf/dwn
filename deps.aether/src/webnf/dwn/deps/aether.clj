(ns webnf.dwn.deps.aether
  "This program discovers a maven dependency graph from a sequence of
  root dependencies. It discovers the full graph, including dependency
  circles and conflicting dependencies."
  (:import
   java.nio.file.Files
   java.nio.file.attribute.FileAttribute
   java.io.PushbackReader)
  (:require [webnf.dwn.deps.aether.cons :as cons]
            ;; [webnf.nix.data :as data]
            [webnf.nix.aether :refer [coordinate-info]]
            [clojure.pprint :refer [pprint]]
            [clojure.java.io :as io]
            [clojure.edn :as edn]
            [clojure.string :as str]))

(def default-repositories
  {"central" "http://repo1.maven.org/maven2"
   "clojars" "https://clojars.org/repo"})

;; Utilities

(defn temp-local-repo
  "Create a temporary maven directory, that is GC'd on process termination"
  []
  (-> (Files/createTempDirectory "m2-" (into-array FileAttribute []))
      .toFile (doto .deleteOnExit)
      cons/local-repository))

(defn memoize-singular
  "A more meticular memoize, which runs the expensive computation at most once"
  [f]
  (let [memo (atom {})]
    (fn [& args]
      (if-let [v (get @memo args)]
        @v
        @(get (swap! memo (fn [m]
                            (let [prev-delay (get m args)]
                              ;; This check needs to happen, in addition to the double reference,
                              ;; since we run file downloads in parallel
                              (if (nil? prev-delay)
                                (assoc m args (delay (apply f args)))
                                m))))
              args)))))

;; Constructors for representative clojure data structures from maven objects

(defn coordinate
  "Parse full artifact coordinate [~group ~artifact ~extension ~classifier ~version]"
  [art]
  [(.getGroupId art)
   (.getArtifactId art)
   (.getExtension art)
   (.getClassifier art)
   (.getVersion art)])

(defn short-coordinate
  "Parse shortened down version of artifact coordinate, as allowed by applicable defaults [(= ~group ~artifact) (= ~extension \"jar\") (= ~classifier \"\")]
  Extreme case: [~group-artifact ~version]"
  [art]
  (let [g (.getGroupId art)
        a (.getArtifactId art)
        e (.getExtension art)
        c (.getClassifier art)
        v (.getVersion art)]
    (vec
     (concat
      (if (= g a) [a] [g a])
      (when (not= "jar" e) [e])
      (when (not (str/blank? c)) [c])
      [v]))))

(defn exclusion
  "Parse exclusion: [~group-artifact] or [~group ~artifact] or [~group-artifact ~options] or [~group ~artifact ~options]"
  [excl]
  (let [g (.getGroupId excl)
        a (.getArtifactId excl)
        e (.getExtension excl)
        c (.getClassifier excl)
        o (cond-> {}
            (not= "*" e) (assoc "extension" e)
            (not= "*" c) (assoc "classifier" c))]
    (vec
     (concat
      (if (= g a) [a] [g a])
      (when-not (empty? o) [o])))))

(defn dependency [dep]
  (let [s (.getScope dep)
        o (.isOptional dep)
        e (mapv exclusion (.getExclusions dep))
        om (cond-> {}
             (not= "compile" s) (assoc "scope" s)
             o (assoc "optional" o)
             (not (empty? e)) (assoc "exclusions" e))]
    (cond-> (short-coordinate (.getArtifact dep))
      (not (empty? om)) (conj om))))

(defn get-dependencies [desc done {:keys [include-optionals include-scopes]}]
  (->> (cond-> (.getDependencies desc)
         (not include-optionals) (->> (remove #(.isOptional %))))
       (filter #(contains? include-scopes (.getScope %)))
       (remove #(contains? done (coordinate (.getArtifact %))))
       (mapv dependency)))

(defn maven-download-info [coord' {:as config}]
  (let [coord (coordinate-info coord')
        art (cons/artifact coord)
        rv (.getVersion (or (cons/version-resolution art config)
                            art))
        rart (-> (coordinate art)
                 coordinate-info
                 (assoc 4 rv)
                 cons/artifact)
        desc (cons/artifact-descriptor rart config)
        res {:coord coord
             :resolved-version rv
             :snapshot (.isSnapshot art)}]
    (if-let [layout (try (cons/repository-layout (.getRepository desc) config)
                         (catch Exception e
                           (println "ERROR" "no download info" (coordinate rart) (.getRepository desc))))]
      (let [base (.. desc getRepository getUrl)
            loc (.getLocation layout rart false)
            cs-loc (some #(when (= "SHA-1" (.getAlgorithm %))
                            (.getLocation %))
                         (.getChecksums layout rart false loc))]
        (assoc res
               :dependencies (get-dependencies desc #{} config)
               :sha1 (try (slurp (str base "/" cs-loc))
                          (catch Exception e
                            (println "ERROR" "couldn't fetch sha-1" base cs-loc)
                            nil))))
      res)))

(defn download-info [coord' {:as config :keys [overlay]}]
  (let [{:keys [group artifact extension classifier version]
         :as coord} (coordinate-info coord')]
    (if-let [{:strs [sha1 dirs jar dependencies]} (get-in overlay [group artifact extension classifier version])]
      {:sha1 sha1
       :dirs dirs
       :jar jar
       :coord coord
       :dependencies dependencies}
      (maven-download-info coord config))))

(defn dependency-coordinate [dep]
  (coordinate (.getArtifact (cons/dependency (coordinate-info dep)))))

(defn expand-download-info
  ([art conf] (expand-download-info art conf #{}))
  ([art {:keys [m-dl-info] :as conf} done]
   (lazy-seq
    (let [{:keys [coord dependencies]
           :as res} (m-dl-info art)
          done' (into done (map dependency-coordinate dependencies))
          thunks (mapv #(future
                          (let [coord (dependency-coordinate %)]
                            (when-not (contains? done coord)
                              (expand-download-info
                               coord conf (disj done' coord)))))
                       dependencies)]
      (cons res (mapcat deref thunks))))))

(defn expand-download-infos
  ([coordinates conf] (mapcat #(expand-download-info % conf) coordinates)))

(defn repo-for [coordinates conf]
  (let [download-infos (expand-download-infos coordinates conf)]
    (reduce (fn [res {:as dli :keys [resolved-version sha1 dirs jar dependencies]
                      {:keys [group artifact extension classifier version]} :coord}]
              (assoc-in res [group artifact extension classifier version]
                        (cond-> {}
                          (and
                           (empty? dirs)
                           (str/blank? jar)
                           (not= resolved-version version)) (assoc :resolved-version resolved-version)
                          (not (str/blank? sha1)) (assoc :sha1 sha1)
                          (not (empty? dirs)) (assoc :dirs dirs)
                          (not (str/blank? jar)) (assoc :jar jar)
                          (not (empty? dependencies)) (assoc :dependencies dependencies))))
            {} download-infos)))

(defn merge-aether-config [prev-config & {:as next-config}]
  (let [{:keys [system session local-repo offline transfer-listener overlay
                mirror-selector repositories include-optionals include-scopes]
         :as config}
        (merge prev-config next-config)]
    (-> {:system (or system @cons/default-repo-system)
         :local-repo (or local-repo (temp-local-repo))
         :offline (boolean offline)
         :include-optionals (if (contains? config :include-optionals)
                              (boolean include-optionals)
                              true)
         :include-scopes (or include-scopes #{"compile" "runtime" "provided" "system" "test"})
         :overlay overlay}
        (as-> config
            (assoc config :session (or session (cons/session config)))
            (assoc config :repositories (cons/repositories (or repositories default-repositories) config))

            (assoc config :m-dl-info
                   (memoize-singular #(download-info % config)))))))

(defn aether-config [& {:keys [system session local-repo offline transfer-listener mirror-selector repositories] :as config}]
  (merge-aether-config config))

(defn -main [repo-out-file coordinates-str repos-str overlay-str]
  (let [repo (repo-for (edn/read-string coordinates-str)
                       (aether-config :include-optionals false
                                      :include-scopes #{"compile"}
                                      :overlay (edn/read-string overlay-str)
                                      :repositories
                                      (into {}
                                            (for [r (edn/read-string repos-str)]
                                              [(str (gensym "repo")) r]))))]
    (with-open [o (io/writer repo-out-file)]
      (binding [*out* o]
        (pprint repo)))
    (shutdown-agents)
    (System/exit 0)))

(comment

  (def cfg (aether-config :include-optionals false
                          :include-scopes #{"compile"}
                          :repositories default-repositories))

  (with-open [o (io/writer #_"/home/herwig/checkout/webnf/dwn/deps.aether/bootstrap-repo.edn"
                           "/tmp/repo.edn")]
    (binding [*out* o]
      (clojure.pprint/pprint
       (repo-for [["org.clojure" "clojure" "1.9.0-alpha14"]
                  ["org.apache.maven" "maven-aether-provider" "3.3.9"]
                  ["org.eclipse.aether" "aether-transport-file" "1.1.0"]
                  ["org.eclipse.aether" "aether-transport-wagon" "1.1.0"]
                  ["org.eclipse.aether" "aether-connector-basic" "1.1.0"]
                  ["org.eclipse.aether" "aether-impl" "1.1.0"]
                  ["org.apache.maven.wagon" "wagon-provider-api" "2.10"]
                  ["org.apache.maven.wagon" "wagon-http" "2.10"]
                  ["org.apache.maven.wagon" "wagon-ssh" "2.10"]]
                 cfg))))

  (with-open [o (io/writer #_"/home/herwig/checkout/webnf/dwn/deps.aether/bootstrap-repo.edn"
                           "/tmp/repo.edn")]
    (binding [*out* o]
      (clojure.pprint/pprint
       (repo-for [["org.clojure" "spec.alpha" "0.1.94"
                   {"exclusions" [["org.clojure" "clojure"]]}]
                  ["org.clojure" "core.specs.alpha" "0.1.10"
                   {"exclusions" [["org.clojure" "clojure"]
                                  ["org.clojure" "spec.alpha"]]}]]
                 cfg))))

  (expand-download-info ["org.eclipse.aether" "aether-impl" "1.1.0"] cfg)

  )
