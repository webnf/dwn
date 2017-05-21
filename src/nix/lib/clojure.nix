{ stdenv, newScope, jdk, lib, writeScript, writeText, fetchurl, runCommand
, copyPathToStore }:

let callPackage = newScope thisns;
    lib' = lib // {
      types = lib.types // {
        symbol = lib.mkOptionType {
          name = "symbol";
          merge = lib.mergeOneOption;
          check = s: ! lib.hasPrefix ":" s;
        };
        keyword = lib.mkOptionType {
          name = "keyword";
          merge = lib.mergeOneOption;
          check = lib.hasPrefix ":";
        };
      };
    };
    thisns = { inherit callPackage; } // rec {
  defaultMavenRepos = [ http://repo1.maven.org/maven2
                        https://clojars.org/repo ];
  dwn = callPackage ./dwn.nix {};
  edn = callPackage ./edn.nix {};

  inherit (edn) asEdn toEdn toEdnPP;
  inherit (edn.syntax) tagged hash-map keyword-map list vector set symbol keyword string int bool nil;
  inherit (edn.data) get get-in eq nth nix-str nix-list extract;

  lib = lib';

  shellBinder = rec {

    classLauncher = { name, classpath, class, jvmArgs ? []
                    , prefixArgs ? [], suffixArgs ? [], debug ? false }:
      writeScript name ''
        #!/bin/sh
        ${if debug then "set -vx" else ""}
        exec ${jdk.jre}/bin/java \
          -cp ${renderClasspath classpath} \
          ${toString jvmArgs} \
          ${class} \
          ${toString prefixArgs} \
          "$@" ${toString suffixArgs}
      '';

    scriptLauncher = { name, classpath, codes, jvmArgs ? [], debug ? false }:
      classLauncher {
        inherit name classpath jvmArgs debug;
        class = "clojure.main";
        prefixArgs = [ "-e" ''
          "$(cat <<CLJ62d3c200-34d4-49e5-a64d-f6eaf59b4715
          ${lib.concatStringsSep "\n\n;; ----\n\n" codes}
          CLJ62d3c200-34d4-49e5-a64d-f6eaf59b4715
          )"
        '' ];
      };

    mainLauncher = { name, classpath, namespace, jvmArgs ? []
                   , prefixArgs ? [], suffixArgs ? [], debug ? false }:
      classLauncher {
        inherit name classpath jvmArgs suffixArgs debug;
        class = "clojure.main";
        prefixArgs = [ "-m" namespace ] ++ prefixArgs;
      };

  };

  descriptorPaths = desc:
  let pkg = lib.elemAt desc 2;
  in if pkg == "dirs"
   then lib.elemAt desc 5
   else if pkg == "jar"
   then [ (lib.elemAt desc 5) ]
   else throw "Unknown packaging '${pkg}'";

  artifactClasspath = args@{
      name
    , cljSourceDirs ? []
    , javaSourceDirs ? []
    , resourceDirs ? []
    , aot ? []
    , compilerOptions ? {}
    , providedVersions ? []
    , devMode ? true
    , ...
  }: let
    baseClasspath = resourceDirs ++ dependencyClasspath args ++ (
      lib.concatLists (map descriptorPaths providedVersions)
    );
    javaClasses = if lib.length javaSourceDirs > 0
      then [ (jvmCompile {
        name = name + "-java-classes";
        classpath = baseClasspath;
        sources = javaSourceDirs;
      }) ] else [];
    cljClasses = if (lib.length cljSourceDirs > 0) && (lib.length aot > 0)
      then [ (cljCompile {
        name = name + "-clj-classes";
        classpath = cljSourceDirs ++ javaSourceDirs ++ javaClasses ++ baseClasspath;
        inherit aot;
        options = compilerOptions;
      }) ] else [];
  in (map (sourceDir devMode) cljSourceDirs)
     ++ cljClasses
     ++ javaClasses
     ++ resourceDirs;

  classpathFor = args: artifactClasspath args ++ dependencyClasspath args;

  expandDependencies = {name
                       , dependencies ? []
                       , overlayRepo ? {}
                       , fixedVersions ? []
                       , providedVersions ? []
                       , fixedDependencies ? null # bootstrap hack
                       , closureRepo ? throw "Please pre-generate the repository add attribute `closureRepo = ./repo.edn;` to project `${name}`"
                       , ... }:
    if isNull fixedDependencies
    then import (depsExpander closureRepo dependencies fixedVersions providedVersions)
    else fixedDependencies;

  dependencyClasspath = args@{ mavenRepos ? defaultMavenRepos
                             , ... }:
    lib.concatLists (map (mvnResolve mavenRepos) (expandDependencies args));

  generateClosureRepo = { dependencies ? []
                        , mavenRepos ? defaultMavenRepos
                        , fixedVersions ? []
                        , overlayRepo ? {}
                        , ... }:
    aetherDownload mavenRepos (dependencies ++ fixedVersions) overlayRepo;

  aetherDownload = repos: deps: overlay: runCommand "repo.edn" {
    ednRepos = toEdn repos;
    ednDeps = toEdn deps;
    ednOverlay = toEdn overlay;
    runner = callPackage ../../../deps.aether { };
  } ''
    #!/bin/sh
    ## set -xv
    exec $runner $out "$ednDeps" "$ednRepos" "$ednOverlay"
  '';
  depsExpander = repo: deps: fixedVersions: providedVersions: runCommand "deps.nix" {
    inherit repo;
    ednDeps = toEdn deps;
    ednFixedVersions = toEdn fixedVersions;
    ednProvidedVersions = toEdn providedVersions;
    launcher = callPackage ../../../deps.expander { };
  } ''
    #!/bin/sh
    ## set -xv
    exec $launcher $out "$repo" "$ednDeps" "$ednFixedVersions" "$ednProvidedVersions";
  '';

  artifactDescriptor = mavenRepos: args@{ coordinate
                                        , dirs ? null
                                        , ...}:
    coordinate ++ (if "dirs" == lib.elemAt coordinate 2
      then [dirs]
      else mvnResolve mavenRepos args
    );

  projectDescriptor = args@{
                        name
                      , mainNs ? {}
                      , components ? {}
                      , mavenRepos ? defaultMavenRepos
                      , providedVersions ? []
                      , ... }:
                      binder@{
                        parentLoader ? keyword "dwn.base" "app-loader"
                      , ...}:
  let containerName = keyword name "container"; in
  keyword-map ({
      "${name}/container" = dwn.container {
        loaded-artifacts = map (artifactDescriptor mavenRepos) ([{
          coordinate = [ name name "dirs" "" "0"];
          dirs = artifactClasspath args;
        }] ++ expandDependencies args);
        parent-loader = parentLoader;
        inherit providedVersions;
      };
    } // lib.listToAttrs (projectNsLaunchers name containerName mainNs binder
                       ++ projectComponents name containerName components binder));

  projectNsLaunchers = prjName: container: mainNs: { mainArgs ? {}, ... }:
  lib.mapAttrsToList (
      name: ns: {
        name = "${prjName}/${name}";
        value = dwn.ns-launcher {
          inherit container;
          main = symbol null ns;
          args = mainArgs.${name} or [];
        };
      }
  ) mainNs;

  projectComponents = prjName: container: components: { componentConfig ? {}, ... }:
  lib.mapAttrsToList (
      name: { factory, options ? {} }: {
        name = "${prjName}/${name}";
        value = dwn.component {
          inherit factory container;
          config = mkConfig options componentConfig.${name} or {};
        };
      }
  ) components;

  mkConfig = optionsDecl: options: options; ## FIXME validate, fill defaults

  project = args@{
              name
            , mainNs ? {}
            , jvmArgs ? []
            , mavenRepos ? defaultMavenRepos
            , ... }:
            { mainLauncher, ... }@binder:
    let
      classpath = classpathFor args;
      launchers = lib.mapAttrs (
          launcherName: nsName:
            mainLauncher {
              inherit classpath jvmArgs;
              name = launcherName;
              namespace = nsName;
            }
        ) mainNs;
      descriptor = toEdnPP (projectDescriptor args binder);
    in stdenv.mkDerivation {
      inherit name classpath descriptor;
      meta.dwn = {
        inherit launchers descriptor;
        providedVersions = map (artifactDescriptor mavenRepos) ([{
          coordinate = [ name name "dirs" "" "0" ];
          dirs = artifactClasspath args;
        }] ++ expandDependencies args);
      };
      launcherScripts = lib.attrValues launchers;
      closureRepo = generateClosureRepo args;
      buildCommand = ''
        mkdir -p $out/bin $out/share/dwn/classpath
        for l in $launcherScripts; do
          cp $l $out/bin/$(stripHash $l)
        done
        for c in $classpath; do
          ln -s $c $out/share/dwn/classpath/$(stripHash $c)
        done
        echo "$descriptor" > $out/share/dwn.edn
      '';
    };

  jvmCompile = { name, classpath, sources }:
    runCommand name {
      inherit classpath sources;
    } ''
      mkdir -p $out
      ${jdk}/bin/javac -d $out -cp $out:${renderClasspath classpath} `find $sources -name '*.java'`
    '';

  cljCompile = { name, classpath, aot, options ? {} }: let
    boolStr = b: if b then "true" else "false";
    command = { warnOnReflection ? true,
                uncheckedMath ? false,
                disableLocalsClearing ? false,
                elideMeta ? [],
                directLinking ? false
              }: runCommand name {
        inherit classpath aot;
      } ''
        mkdir -p $out
        exec ${jdk.jre}/bin/java \
          -cp $out:${renderClasspath classpath} \
          -Dclojure.compile.path=$out \
          -Dclojure.compiler.warn-on-reflection=${boolStr warnOnReflection} \
          -Dclojure.compiler.unchecked-math=${boolStr uncheckedMath} \
          -Dclojure.compiler.disable-locals-clearing=${boolStr disableLocalsClearing} \
          "-Dclojure.compiler.elide-meta=[${toString elideMeta}]" \
          -Dclojure.compiler.direct-linking=${boolStr directLinking} \
          clojure.lang.Compile $aot
      '';
    in command options;

  combinePathes = name: pathes: runCommand name { inherit pathes; } ''
    mkdir -p out
    for p in $pathes; do
      cp -nR $p/${"*"} out
      chmod -R +w out
    done
    cp -R out $out
  '';

  sourceDir = devMode: dir:
    if devMode
    then toString dir
    else copyPathToStore dir;

  mvnResolve = mavenRepos: { resolved-version ? null, coordinate, sha1 ? null, dirs ? null, ... }:
    if "dirs" == lib.elemAt coordinate 2 then
      dirs
    else
    let version = lib.elemAt coordinate 4;
        classifier = lib.elemAt coordinate 3;
        extension = lib.elemAt coordinate 2;
        name    = lib.elemAt coordinate 1;
        group   = lib.elemAt coordinate 0;
    in [ (fetchurl {
      name = "${name}-${version}.${extension}";
      urls = mavenMirrors mavenRepos group name extension classifier version
                          (if isNull resolved-version then version else resolved-version);
      inherit sha1;
    }) ];

  mavenMirrors = mavenRepos: group: name: extension: classifier: version: resolvedVersion: let
    dotToSlash = lib.replaceStrings [ "." ] [ "/" ];
    tag = if classifier == "" then "" else "-" + classifier;
    mvnPath = baseUri: "${baseUri}/${dotToSlash group}/${name}/${version}/${name}-${resolvedVersion}${tag}.${extension}";
  in map mvnPath mavenRepos;

  renderClasspath = classpath: lib.concatStringsSep ":" classpath;

};
in thisns
