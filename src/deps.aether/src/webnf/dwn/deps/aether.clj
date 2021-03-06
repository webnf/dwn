(ns webnf.dwn.deps.aether
  "This program discovers a maven dependency graph from a sequence of
  root dependencies. It discovers the full graph, including dependency
  circles and conflicting dependencies."
  (:import
   java.nio.file.Files
   java.nio.file.attribute.FileAttribute
   java.io.PushbackReader)
  (:require [webnf.dwn.deps.aether.cons :as cons]
            [webnf.dwn.deps.aether.json :as json]
            ;; [webnf.nix.data :as data]
            [webnf.nix.aether :refer [coordinate-info]]
            [clojure.pprint :as pp :refer [pprint]]
            [clojure.java.io :as io]
            [clojure.edn :as edn]
            [clojure.string :as str]))

(defmacro trace [f & args]
  `(try (let [r# (~f ~@args)]
          (.println *err* (pr-str (list ~f ~@args) '~'=> r#))
          r#)
        (catch Exception e#
          (.println *err* (pr-str (list ~f ~@args) '~'=> e#))
          (throw e#))))

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
    (let [has-classifier (not (str/blank? c))
          has-extension (or has-classifier (not= "jar" e))]
      (vec
       (concat
        (if (= g a) [a] [g a])
        (when has-extension [e])
        (when has-classifier [c])
        [v])))))

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
        mdesc (let [vrr (cons/version-resolution art config)]
                (cond-> (-> art coordinate coordinate-info)
                  vrr (assoc :version (.getVersion vrr))))
        desc (cons/artifact-descriptor
              (cons/artifact mdesc)
              config)
        rart (.getArtifact desc)
        res (assoc mdesc
                   :coord coord
                   :base-version (.getBaseVersion rart))]
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
               :sha1 (try (subs (slurp (str base "/" cs-loc))
                                ;; Fix sha sums with extra characters
                                0 40)
                          (catch Exception e
                            (println "ERROR" "couldn't fetch sha-1" base cs-loc)
                            nil))))
      res)))

(defn download-info [coord' {:as config :keys [overlay]}]
  (let [{:keys [group artifact extension classifier version]
         :as coord} (coordinate-info coord')
        res (if-let [{:strs [sha1 dependencies base-version
                             group artifact extension classifier version]
                      :or {group group artifact artifact extension extension
                           classifier classifier version version base-version version}}
                     (get-in overlay [extension classifier group artifact version])]
              {:sha1 sha1
               :coord coord
               :dependencies dependencies
               :overlay true
               :group group
               :artifact artifact
               :extension extension
               :classifier classifier
               :version version
               :base-version base-version}
              (maven-download-info coord config))]
    res))

(defn dependency-coordinate [dep]
  (coordinate (.getArtifact (cons/dependency (coordinate-info dep)))))

(defn expand-download-info
  ([art conf] (expand-download-info art conf #{}))
  ([art {:keys [m-dl-info] :as conf} done]
   (lazy-seq
    (let [{:keys [coord dependencies]
           :as res} (m-dl-info art)
          done' (into done (map dependency-coordinate) dependencies)
          thunks (mapv #(future
                          (let [coord (dependency-coordinate %)]
                            (when-not (contains? done coord)
                              (expand-download-info
                               coord conf (disj done' coord)))))
                       dependencies)]
      (cons res (mapcat deref thunks))))))

(defn expand-download-infos
  ([coordinates conf]
   (->> coordinates
        (mapv #(future (expand-download-info % conf)))
        (map deref)
        (apply concat))))

(def coord-vec (juxt :group :artifact :extension :classifier :version))

(defn output-entry [{:as coord :keys [group artifact extension classifier version]
                     cg :group ca :artifact ce :extension
                     cc :classifier cv :version}
                    {:as info :keys
                     [group artifact extension classifier version base-version sha1 dependencies]}]
  (cond-> {}
    (not= cg group) (assoc :group group)
    (not= ca artifact) (assoc :artifact artifact)
    (not= ce extension) (assoc :extension extension)
    (not= cc classifier) (assoc :classifier classifier)
    (not= cv version) (assoc :version version)
    (not= cv base-version) (assoc :baseVersion base-version)
    (not (str/blank? sha1)) (assoc :sha1 sha1)
    (not (empty? dependencies)) (assoc :dependencies dependencies)))

(defn repo-for [coordinates conf]
  (let [download-infos (expand-download-infos coordinates conf)]
    (reduce (fn [res {:as dli :keys [overlay]
                      {:as coord :keys [group artifact extension classifier version]}
                      :coord}]
              (if overlay
                res
                (assoc-in res [extension classifier group artifact version]
                          (output-entry coord dli))))
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
      (doseq [s (json/emit-repo repo)]
        (.write o (str s))))
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
       (repo-for [["org.clojure" "clojure" "1.9.0"]
                  ["org.apache.maven" "maven-resolver-provider" "3.6.0"]
                  ["org.apache.maven.resolver" "maven-resolver-transport-file" "1.3.1"]
                  ["org.apache.maven.resolver" "maven-resolver-transport-wagon" "1.3.1"]
                  ["org.apache.maven.resolver" "maven-resolver-connector-basic" "1.3.1"]
                  ["org.apache.maven.resolver" "maven-resolver-impl" "1.3.1"]
                  ["org.apache.maven.wagon" "wagon-provider-api" "3.2.0"]
                  ["org.apache.maven.wagon" "wagon-http" "3.2.0"]
                  ["org.apache.maven.wagon" "wagon-ssh" "3.2.0"]]
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

  (println (apply str (json/emit-repo (repo-for [["net.cgrand" "utils" "0.1.0-20120924.101254-2"]
                                                 ["net.cgrand" "utils" "0.1.0-SNAPSHOT"]
                                                 ;["org.apache.maven" "maven-resolver-provider" "3.6.0"]
                                                 ]
                                                cfg)
                                      )))

  (expand-download-info ["net.cgrand" "utils" "0.1.0-20120924.101254-2"] cfg)

  (expand-download-info ["amazonica" "0.3.139"] cfg)

  (def r (repo-for [["amazonica" "0.3.139"]]
                   cfg))

  (with-open [o (io/writer #_"/home/herwig/checkout/webnf/dwn/deps.aether/bootstrap-repo.edn"
                           "/tmp/repo.edn")]
    (binding [*out* o
              *print-length* false]
      (clojure.pprint/pprint
       r)))

  (cons/artifact {:group "com.amazonaws"
                  :artifact "aws-java-sdk-cloudwatch"
                  :extension "jar"
                  :classifier ""
                  :version "[1.11.115, 2.0.0)"})

  )
