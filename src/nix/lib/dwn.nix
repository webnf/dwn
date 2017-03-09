{ resolveDep, edn, lib, mvnCatalog, cljNsLauncher, toEdn
, renderClasspath, cljCompile, jvmCompile, combinePathes
, keyword-map, symbol, keyword, string, tagged
, nix-list, nix-str, get, extract }:

rec {

  container = tagged (symbol "webnf.dwn" "container");
  component = tagged (symbol "webnf.dwn" "component");
  ns-launcher = tagged (symbol "webnf.dwn" "ns-launcher");

  build = { group, name, version, dependencies
          , repository ? mvnCatalog
          , source-paths ? []
          , java-source-paths ? []
          , aot ? [] }: let
       base-classpath = renderClasspath (
           source-paths ++ java-source-paths
           ++ (lib.concatMap (artefactOutputs repository) dependencies)
         );
       jvmClasses = jvmCompile {
         name = "${group}-${name}-jvm-classes-${version}";
         classpath = base-classpath;
         sources = java-source-paths;
       };
       cljClasses = cljCompile {
         name = "${group}-${name}-clj-classes-${version}";
         classpath = "${jvmClasses}:${base-classpath}";
         inherit aot;
       };
       sources = combinePathes "${group}-${name}-sources-${version}" (
         source-paths ++ java-source-paths
       );
       hasJvm = lib.length java-source-paths > 0;
       hasAot = lib.length aot > 0;
    in combinePathes "${group}-${name}-${version}" (
         (lib.optional hasJvm jvmClasses)
      ++ (lib.optional hasAot cljClasses)
      ++ sources
    ) // {
      inherit jvmClasses cljClasses sources;
      meta.dwn = {
        inherit group name version dependencies repository;
        classpath-output-dirs =
          ## FIXME guard collisions
             (lib.optional hasJvm "jvmClasses")
          ++ (lib.optional hasAot "cljClasses")
          ++ [ "sources" ];
      };
    };

  componentLauncher = cfgFile: componentKey:
    let
      inherit (cfgFile.meta.dwn) config;
      launcherConfig = extract (symbol "webnf.dwn" "ns-launcher")
                               (get config componentKey);
      containerConfig = extract (symbol "webnf.dwn" "container")
                                (get config (get launcherConfig (keyword null "container")));
    in cljNsLauncher {
      name = "launcher";
      classpath = lib.concatMap
        (e:
          let
            sourceDirs = get e (keyword null "source-dirs");
            jarFile = get e (keyword null "jar-file");
          in if isNull sourceDirs
             then [ (nix-str jarFile) ]
             else map nix-str (nix-list sourceDirs))
        (nix-list (get containerConfig (keyword null "classpath")));
      namespace = nix-str (get launcherConfig (keyword null "main"));
      suffixArgs = [ cfgFile ];
    };
}
      
