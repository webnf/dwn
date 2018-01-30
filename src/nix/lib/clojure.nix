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
  project = callPackage ./make-project.nix {};

  inherit (edn) asEdn toEdn toEdnPP;
  inherit (edn.syntax) tagged hash-map keyword-map list vector set symbol keyword string int bool nil;
  inherit (edn.data) get get-in eq nth nix-str nix-list extract;

  inherit (callPackage ./compile.nix {}) jvmCompile cljCompile classesFor;
  inherit (callPackage ./lib-project.nix {})
    sourceDir subProjectOverlay subProjectFixedVersions
    classpathFor artifactClasspath dependencyClasspath;
  inherit (callPackage ./descriptor.nix {})
    projectDescriptor projectNsLaunchers projectComponents artifactDescriptor;
  inherit (callPackage ../../../deps.expander/lib.nix {}) depsExpander expandDependencies;
  inherit (callPackage ../../../deps.aether/lib.nix {}) aetherDownloader closureRepoGenerator;

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

  mergeRepos = lib.recursiveUpdate;
  clojureCustom = callPackage ../../../build-clojure.nix {};

  mapRepoVals = f: repo:
    let mapVals = depth: vals:
      if depth > 0 then
        lib.mapAttrs (_: v: mapVals (depth - 1) v) vals
      else
        f vals;
    in
      mapVals 5 repo;

  filterDirs = overlayRepo:
    mapRepoVals (desc: builtins.removeAttrs desc [ "dirs" "overrideProject" ]) overlayRepo;

  combinePathes = name: pathes: runCommand name { inherit pathes; } ''
    mkdir -p out
    for p in $pathes; do
      cp -nR $p/${"*"} out
      chmod -R +w out
    done
    cp -R out $out
  '';

  unwrapCoord = f: coordinate:
    let
      group = lib.elemAt coordinate 0;
      name = lib.elemAt coordinate 1;
      extension = lib.elemAt coordinate 2;
      classifier = lib.elemAt coordinate 3;
      version = lib.elemAt coordinate 4;
    in
      f group name extension classifier version;

  getRepoCoord = default: repo: unwrapCoord (getRepo default repo);

  getRepo = default: repo: g: n: e: c: v: repo."${g}"."${n}"."${e}"."${c}"."${v}" or default;

  mvnResolve =
        mavenRepos:
        { resolved-coordinate ? coordinate
        , resolved-base-version ? null
        , coordinate
        , sha1 ? null
        , dirs ? null
        , jar ? null
        , ... }:
    let resF = group: name: extension: classifier: version:
             let
               baseVersion = if isNull resolved-base-version then version else resolved-base-version;
             in
               if "dirs" == extension then
                 if isNull dirs then throw "Dirs for ${toString coordinate} not found" else dirs
               else if "jar" == extension
                    && isNull sha1 then
                 if isNull jar then throw "Jar file for ${toString coordinate} not found" else [ jar ]
               else [ ((fetchurl {
                          name = "${name}-${version}.${extension}";
                          urls = mavenMirrors mavenRepos group name extension classifier baseVersion version;
                          inherit sha1;
                                # prevent nix-daemon from downloading maven artifacts from the nix cache
                 })  // { preferLocalBuild = true; }) ];
    in
      unwrapCoord resF coordinate;

  mavenMirrors = mavenRepos: group: name: extension: classifier: version: resolvedVersion: let
    dotToSlash = lib.replaceStrings [ "." ] [ "/" ];
    tag = if classifier == "" then "" else "-" + classifier;
    mvnPath = baseUri: "${baseUri}/${dotToSlash group}/${name}/${version}/${name}-${resolvedVersion}${tag}.${extension}";
  in # builtins.trace "DOWNLOADING '${group}' '${name}' '${extension}' '${classifier}' '${version}' '${resolvedVersion}'"
       (map mvnPath mavenRepos);

  renderClasspath = classpath: lib.concatStringsSep ":" classpath;

};
in thisns
