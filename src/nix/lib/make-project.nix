{ stdenv, lib
, subProjectOverlay
, mergeRepos
, subProjectFixedVersions
, classpathFor
, classesFor
, toEdnPP
, projectDescriptor
, expandDependencies
, artifactClasspath
, artifactDescriptor
, closureRepoGenerator
, defaultMavenRepos
, shellBinder
}:
args0@{
  name
, group ? name
, version ? "0-SNAPSHOT"
, extension ? "dirs"
, classifier ? ""
, dependencies ? []
, fixedVersions ? []
, providedVersions ? []
, closureRepo ? null
, overlayRepo ? {}
, mainNs ? {}
, jvmArgs ? []
, mavenRepos ? defaultMavenRepos
, subProjects ? []
, binder ? shellBinder
, passthru ? {}
, cljSourceDirs ? []
, javaSourceDirs ? []
, resourceDirs ? []
, ... }:

let
  spo = subProjectOverlay args;
  args = args0 // {
    overlayRepo = mergeRepos spo overlayRepo;
    fixedVersions = fixedVersions ++ subProjectFixedVersions subProjects;
  };
  classpath = classpathFor args;
  launchers = lib.mapAttrs (
      launcherName: nsName:
        binder.mainLauncher {
          inherit classpath jvmArgs;
          name = launcherName;
          namespace = nsName;
        }
    ) mainNs;
  descriptor = toEdnPP (projectDescriptor args binder);
  project = stdenv.mkDerivation {
    inherit classpath descriptor;
    name = "${name}-${version}";
    passthru = lib.recursiveUpdate {
      dwn = {
        artifact = name;
        coordinate = [ group name extension classifier version ];
        inherit group extension classifier version;
        inherit launchers subProjects;
        inherit mainNs jvmArgs mavenRepos;
        inherit dependencies providedVersions closureRepo;
        inherit cljSourceDirs javaSourceDirs resourceDirs;
        expandedDependencies = expandDependencies args;
        subProjectOverlay = spo;
        inherit (args) overlayRepo fixedVersions;
        dirs = if extension == "dirs" then artifactClasspath args else null;
        jar = if extension == "jar" then throw "Not implemented: ${extension}" else null;
        classes = classesFor args;
      };
      overrideProject = overrideFn: project (args // (overrideFn args));
    } passthru;
    meta.dwn = (lib.warn "Deprecated usage of <project>.meta.dwn ; use <project>.dwn instead" {
      inherit launchers descriptor;
      providedVersions = map (artifactDescriptor mavenRepos) ([{
        coordinate = [ name name "dirs" "" "0" ];
        dirs = artifactClasspath args;
      }] ++ expandDependencies args);
    });
    launcherScripts = lib.attrValues launchers;
    closureRepoGenerator = closureRepoGenerator args;
    buildCommand = ''
      mkdir -p $out/bin $out/share/dwn/classpath
      for l in $launcherScripts; do
        cp $l $out/bin/$(stripHash $l)
      done
      for c in $classpath; do
        local targetOrig=$out/share/dwn/classpath/$(stripHash $c)
        local target=$targetOrig
        local cnt=0
        while [ -L $target ]; do
          target=$targetOrig-$cnt
          cnt=$(( cnt + 1 ))
        done
        ln -s $c $target
      done
      echo "$descriptor" > $out/share/dwn.edn
    '';
  };
in project
