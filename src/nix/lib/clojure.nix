{ stdenv, newScope, jdk, lib, writeScript, fetchurl, runCommand }:

let callPackage = newScope thisns;
    thisns = { inherit callPackage; } // rec {
  defaultMavenRepos = [ http://repo1.maven.org/maven2
                        https://clojars.org/repo ];
  dwn = callPackage ./dwn.nix {};
  edn = callPackage ./edn.nix {};

  inherit (edn) asEdn toEdn toEdnPP;
  inherit (edn.syntax) tagged hash-map keyword-map list vector set symbol keyword string int bool nil;
  inherit (edn.data) get get-in eq nth nix-str nix-list extract;

  inherit lib;

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

  compiledClasspath = {
      name, dependencyClasspath
    , cljSourceDirs ? []
    , javaSourceDirs ? []
    , resourceDirs ? []
    , aot ? []
    , compilerOptions ? {}
    , devMode ? true
    , ...
  }: let
    baseClasspath = resourceDirs ++ dependencyClasspath;
    javaClasses = if lib.length javaSourceDirs > 0 then [ (jvmCompile {
        name = name + "-java-classes";
        classpath = baseClasspath;
        sources = javaSourceDirs;
    }) ] else [];
    cljClasses = if lib.length cljSourceDirs > 0 then [ (cljCompile {
        name = name + "-clj-classes";
        classpath = cljSourceDirs ++ javaSourceDirs ++ javaClasses ++ baseClasspath;
        inherit aot;
        options = compilerOptions;
    }) ] else [];
  in cljSourceDirs ++ javaSourceDirs ++ cljClasses ++ javaClasses ++ baseClasspath;

  generateDependencyClasspath = { dependencies ? []
                        , closureRepo ? throw "Please pre-generate the repository for this closure"
                        , mavenRepos ? defaultMavenRepos
                        , fixedVersions ? []
                        , ... }:
    map (mvnResolve mavenRepos) (import (depsExpander closureRepo dependencies fixedVersions));

  generateClosureRepo = { dependencies ? []
                        , mavenRepos ? defaultMavenRepos
                        , fixedVersions ? []
                        , ... }:
    aetherDownload mavenRepos (dependencies ++ fixedVersions);

  aetherDownload = repos: deps: runCommand "repo.edn" {
   mvnRepos = toEdn repos;
   mvnDeps = toEdn deps;
   runner = callPackage ../../../deps.aether { };
  } ''
    #!/bin/sh
    exec $runner $out "$mvnDeps" "$mvnRepos"
  '';
  depsExpander = repoEdn: deps: fixedVersions: runCommand "deps.nix" {
    inherit repoEdn;
    mvnDeps = toEdn deps;
    mvnFixedVersions = toEdn fixedVersions;
    launcher = callPackage ../../../deps.expander { };
  } ''
    #!/bin/sh
    exec $launcher $out "$mvnDeps" "$repoEdn" "$mvnFixedVersions";
  '';

  projectClasspath = args: compiledClasspath (args // {
    dependencyClasspath = generateDependencyClasspath args;
  });

  project = args@{
      name
    , mainNs ? {}
    , jvmArgs ? []
    , ...
    }: let
      classpath = projectClasspath args;
    in stdenv.mkDerivation {
      inherit name classpath;
      closureRepo = import (generateClosureRepo args);
      launchers = lib.mapAttrsToList (
          launcherName: nsName:
            mainLauncher {
              inherit classpath jvmArgs;
              name = launcherName;
              namespace = nsName;
            }
        ) mainNs;
      buildCommand = ''
        mkdir -p $out/bin $out/share/dwn/classpath
        for l in $launchers; do
          cp $l $out/bin/$(stripHash $l)
        done
        for c in $classpath; do
          ln -s $c $out/share/dwn/classpath/$(stripHash $c)
        done
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
/*
  sourceDirs = name: meta: dirs:
    if devMode
    then lib.fold (dir: d@{ outputs, ... }:
                   let
                     outName = "out-${toString (lib.length outputs)}";
                   in d // {
                     outputs = outputs ++ [ outName ];
                     "${outName}" = toString dir;
                   })
                  { type = "derivation";
                    outputs = [];
                    inherit meta; }
                  dirs
    else lib.recursiveUpdate (combinePathes name dirs)
                             { inherit meta; };
*/
  ## Maven

  mvnResolve = mavenRepos: { resolved-version, coordinate, sha1, ... }:
    let version = lib.elemAt coordinate 2;
        name    = lib.elemAt coordinate 1;
        group   = lib.elemAt coordinate 0;
    in fetchurl {
      name = "${name}-${version}.jar";
      urls = mavenMirrors mavenRepos group name version resolved-version;
      inherit sha1;
    };

  mavenMirrors = mavenRepos: group: name: version: resolvedVersion: let
    dotToSlash = lib.replaceStrings [ "." ] [ "/" ];
    mvnPath = baseUri: "${baseUri}/${dotToSlash group}/${name}/${version}/${name}-${resolvedVersion}.jar";
  in map mvnPath mavenRepos;

  ## utilities / data structures

  renderClasspath = classpath: lib.concatStringsSep ":" classpath;

};
in thisns
