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
  inherit (callPackage ./shell-binder.nix {}) renderClasspath shellBinder;
  inherit (callPackage ../../../deps.expander/lib.nix {}) depsExpander expandDependencies;
  inherit (callPackage ../../../deps.aether/lib.nix {}) aetherDownloader closureRepoGenerator;
  inherit (callPackage ./repository.nix {})
    mergeRepos descriptorPaths mapRepoVals filterDirs
    mavenMirrors mvnResolve getRepo getRepoCoord unwrapCoord;

  lib = lib';

  clojureCustom = callPackage ../../../clojure {};

  combinePathes = name: pathes: runCommand name { inherit pathes; } ''
    mkdir -p out
    for p in $pathes; do
      cp -nR $p/${"*"} out
      chmod -R +w out
    done
    cp -R out $out
  '';

};
in thisns
