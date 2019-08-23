(ns webnf.dwn.lein.reader
  (:require [leiningen.core.project :as prj]
            [clojure.java.io :as io]
            [clojure.pprint :as pp]
            [webnf.nix.data :as nix-data]))


(defn warn [fmt & args]
  (.println *err* (str "WARNING: " (apply format fmt args))))

(defn key-selector [prj f]
  #(assoc %1 %2 (f (get prj %2))))

(defn exclusion [[artifact :as args]]
  (let [g (or (namespace artifact)
              (name artifact))
        a (name artifact)]
    [g a]))

(defn coord [[artifact version & {:as props :keys [exclusions scope extension classifier]}]]
  (let [p (dissoc props :exclusions :scope :extension :classifier)]
    (when-not (empty? p)
      (warn "Don't know how to emit props %s" (pr-str p))))
  (let [g (or (namespace artifact)
              (name artifact))
        a (name artifact)
        p (cond-> {}
            exclusions (assoc "exclusions" (mapv exclusion exclusions))
            scope      (assoc "scope" scope))]
    (cond-> [g a
             (or extension "jar")
             (or classifier "")
             version]
      (not (empty? p)) (conj p))))

(def path nix-data/path)

(defn dedupe-all [xf]
  (let [unseen (Object.)
        seen (volatile! (transient #{}))]
    (fn
      ([s] (vreset! seen nil) s)
      ([s v] (if (identical? unseen
                             (get @seen v unseen))
               (do
                 (vswap! seen conj! v)
                 (xf s v))
               s)))))

(defn select-coords [r prj & coord-keys]  
  (reduce (key-selector prj #(nix-data/as-hvec (mapv coord %)))
          r coord-keys))

(defn canonical-path [^java.io.File f]
  (.getCanonicalPath f))

(defn file-exists? [^java.io.File f]
  (.exists f))

(defn select-paths [r prj & path-keys]
  (reduce (key-selector prj #(nix-data/as-hvec
                              (into []
                                    (comp
                                     (map io/file)
                                     ;; we cannot access files during nix build,
                                     ;; due to access control
                                     ;; (filter file-exists?)
                                     (map canonical-path)
                                     dedupe-all
                                     (map path))
                                    %)))
          r path-keys))

(defn rename-keys [m0 & ks0]
  (loop [m                    m0
         [k0 k1 & nxt :as ks] ks0]
    (if (seq ks)
      (recur (-> m
                 (dissoc k0)
                 (assoc k1 (get m k0)))
             nxt)
      m)))

(defn get-main-ns [prj]
  (into {}
        (map (fn [main]))
        (:main prj)))

(defn -main [& args']
  (let [[project-clj base-dir op & args] args']
    ;; (apply println "Hello, got" args)
    (assert (.isFile (io/file (str project-clj))) (pr-str project-clj))
    (assert (= "pr-deps" op) (pr-str op))
    (assert (= nil args) (pr-str args))
    (-> (prj/read-raw project-clj)
        (assoc :root (io/file base-dir))
        (prj/project-with-profiles)
        (prj/init-profiles [:base :system :user :provided :dev])
        (as-> #__ prj
          (-> {}
              (select-coords prj :dependencies :plugins)
              (select-paths prj :source-paths :resource-paths :java-source-paths)
              (assoc :aot (mapv name (:aot prj)))
              (assoc
               :group   (:group prj)
               :name    (:name prj)
               :version (:version prj))
              (cond-> (:main prj) (assoc :mainNs {:main (str (:main prj))}))))
        (rename-keys
         :source-paths      :cljSourceDirs
         :resource-paths    :resourceDirs
         :java-source-paths :javaSourceDirs)
        ;; pp/pprint
        nix-data/nixprn))
  (System/exit 0))
