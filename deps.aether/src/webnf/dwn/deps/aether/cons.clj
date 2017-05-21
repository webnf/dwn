(ns webnf.dwn.deps.aether.cons
  (:import
   (org.eclipse.aether RepositorySystem RepositorySystemSession)
   (org.eclipse.aether.resolution ArtifactDescriptorRequest
                                  ArtifactDescriptorResult
                                  ArtifactDescriptorException)
   (org.eclipse.aether.repository LocalRepository RemoteRepository$Builder)
   (org.apache.maven.repository.internal MavenRepositorySystemUtils)
   (org.apache.maven.wagon.providers.http HttpWagon)
   (org.apache.maven.artifact.versioning DefaultArtifactVersion ArtifactVersion)
   org.eclipse.aether.graph.Dependency
   org.eclipse.aether.graph.Exclusion
   org.eclipse.aether.artifact.Artifact
   org.eclipse.aether.artifact.DefaultArtifact
   (org.eclipse.aether.collection CollectRequest)
   (org.eclipse.aether.metadata Metadata Metadata$Nature DefaultMetadata)
   org.eclipse.aether.resolution.VersionResult
   org.eclipse.aether.resolution.VersionRequest
   org.eclipse.aether.resolution.VersionResolutionException
   (org.eclipse.aether.repository RemoteRepository Proxy ArtifactRepository Authentication
                                  RepositoryPolicy LocalRepository RemoteRepository
                                  MirrorSelector RemoteRepository$Builder)
   (org.eclipse.aether.spi.connector RepositoryConnectorFactory)
   (org.eclipse.aether.spi.connector.layout RepositoryLayoutProvider)
   (org.eclipse.aether.connector.basic BasicRepositoryConnectorFactory)
   org.eclipse.aether.spi.connector.layout.RepositoryLayoutProvider
   org.eclipse.aether.spi.connector.layout.RepositoryLayout
   org.eclipse.aether.spi.connector.transport.GetTask
   org.eclipse.aether.spi.connector.transport.Transporter
   org.eclipse.aether.spi.connector.transport.TransporterProvider
   org.eclipse.aether.transfer.NoRepositoryLayoutException
   org.eclipse.aether.transfer.NoTransporterException
   (org.eclipse.aether.spi.connector.transport TransporterFactory)
   (org.eclipse.aether.transport.file FileTransporterFactory)
   (org.eclipse.aether.transport.wagon WagonProvider WagonTransporterFactory)
   org.eclipse.aether.util.version.GenericVersionScheme)
  (:require [clojure.java.io :as io]
            [clojure.spec.alpha :as s]
            [clojure.stacktrace :as st]
            [clojure.string :as str]
            [webnf.nix.aether :refer [coordinate-string]]))

; Using HttpWagon (which uses apache httpclient) because the "LightweightHttpWagon"
; (which just uses JDK HTTP) reliably flakes if you attempt to resolve SNAPSHOT
; artifacts from an HTTPS password-protected repository (like a nexus instance)
; when other un-authenticated repositories are included in the resolution.
; My theory is that the JDK HTTP impl is screwing up connection pooling or something,
; and reusing the same connection handle for the HTTPS repo as it used for e.g.
; central, without updating the authentication info.
; In any case, HttpWagon is what Maven 3 uses, and it works.

(def wagon-factories (atom {"http" #(HttpWagon.)
                            "https" #(HttpWagon.)}))

(defn register-wagon-factory!
  "Registers a new no-arg factory function for the given scheme.  The function must return
   an implementation of org.apache.maven.wagon.Wagon."
  [scheme factory-fn]
  (swap! wagon-factories (fn [m]
                           (when-let [fn (m scheme)]
                             (println (format "Warning: replacing existing support for %s repositories (%s) with %s" scheme fn factory-fn)))
                           (assoc m scheme factory-fn))))

(deftype PomegranateWagonProvider []
  WagonProvider
  (release [_ wagon])
  (lookup [_ role-hint]
    (when-let [f (get @wagon-factories role-hint)]
      (try 
        (f)
        (catch Exception e
          (st/print-cause-trace e)
          (throw e))))))

(def default-service-locator
  (delay (doto (MavenRepositorySystemUtils/newServiceLocator)
           (.addService RepositoryConnectorFactory BasicRepositoryConnectorFactory)
           (.addService TransporterFactory FileTransporterFactory)
           (.addService TransporterFactory WagonTransporterFactory)
           (.addService WagonProvider PomegranateWagonProvider))))

(defn- factory [cls & [wrap-fn]]
  (delay (let [res (.getService @default-service-locator cls)]
           (if wrap-fn
             (wrap-fn res)
             res))))

(def default-repo-system (factory RepositorySystem))
(def default-repo-layout-provider (factory RepositoryLayoutProvider))

(s/def ::binding any?)

(s/def ::argv (s/coll-of ::binding :kind vector?))

(s/def ::arity
  (s/cat :argv ::argv
         :body (s/* any?)))

(s/def ::defc-single
  (s/cat :argv (s/and ::argv (s/cat :arg ::binding))
         :body (s/* any?)))

(s/def ::defc-multi
  (s/cat :single (s/and list? ::defc-single)
         :extra (s/* (s/and list? ::arity))))

(s/def ::defc-tail
  (s/cat :docstring (s/? string?)
         :attr-map (s/? map?)
         :definition (s/alt :single ::defc-single :multi ::defc-multi)))

(defmacro defc [name class & [docstring? attr-map? [[arg] & constructor-arity] & fn-tail :as tail]]
  (let [{:keys [docstring attr-map]
         [deft defv] :definition
         :as parsed}
        (s/conform ::defc-tail tail)
        _ (when (s/invalid? parsed)
            (throw (ex-info (s/explain-str ::defc-tail tail)
                            (s/explain-data ::defc-tail tail))))
        {{arg :arg} :argv constructor-arity :body fn-tail :fn-tail}
        (case deft
          :single defv
          :multi (assoc (:single defv)
                        :fn-tail (map #(s/unform ::arity %)
                                      (:extra defv))))]
    `(defn ~name
       ~@(remove nil? [docstring attr-map])
       ([arg#] (if (instance? ~class arg#) arg#
                   (let [~arg arg#] ~@constructor-arity)))
       ~@fn-tail)))

(defc local-repository LocalRepository
  ([path] (LocalRepository. (.getAbsolutePath (io/file path)))))

(defc session RepositorySystemSession [{:keys [system local-repo offline transfer-listener mirror-selector]}]
  (-> (MavenRepositorySystemUtils/newSession)
      (.setOffline (boolean offline))
      (cond-> transfer-listener (.setTransferListener transfer-listener)
              mirror-selector (.setMirrorSelector mirror-selector))
      (as-> session
          (.setLocalRepositoryManager
           session (.newLocalRepositoryManager system session local-repo)))))

(defn repository-layout [repository {:keys [session]}]
  (.newRepositoryLayout @default-repo-layout-provider session repository))

(defc repository RemoteRepository [[id settings]]
  (let [settings-map (if (string? settings)
                       {:url settings}
                       settings)]
    (.. (RemoteRepository$Builder. id
                                   (:type settings-map "default")
                                   (str (:url settings-map)))
                                        ;(setPolicy (policy settings (:releases settings true)))
                                        ;(setSnapshotPolicy (policy settings (:snapshots settings true)))
        build)))

(defn repositories [repos {:keys [system session]}]
  (.newResolutionRepositories system session (mapv repository repos)))

(defc exclusion Exclusion
  [{:keys [group artifact classifier extension]}]
  (Exclusion. group artifact classifier extension))

(defc artifact Artifact
  [coord]
  (DefaultArtifact. (coordinate-string coord)))

(def gvs (GenericVersionScheme.))

(defc version ArtifactVersion [s]
  (.parseVersion gvs s))

(defc dependency Dependency
  [{:keys [scope optional exclusions] :as spec}]
  (Dependency. (artifact spec)
               scope
               optional
               (map exclusion exclusions)))


(defn collection-request [deps {:keys [repositories]}]
  (CollectRequest. (mapv dependency deps) nil repositories))

(defn artifact-descriptor [dep {:keys [repositories system session]}]
  (.readArtifactDescriptor
   system session
   (ArtifactDescriptorRequest. (artifact dep) repositories nil)))

(defn version-resolution [art {:keys [system session repositories] :as conf}]
  (.resolveVersion system session (VersionRequest. (artifact art) repositories nil)))

(defc metadata Metadata [art]
  (let [a (artifact art)]
    (DefaultMetadata.
     (.getGroupId a)
     (.getArtifactId a)
     (.getVersion a)
     "maven-metadata.xml"
     Metadata$Nature/RELEASE_OR_SNAPSHOT)))
