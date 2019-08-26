{ lib, copyPathToStore
, mergeRepos
, classesFor
, defaultMavenRepos
, mvnResolve
, expandDependencies
, dependencyClasspath
, mapRepoVals
}:

rec {
  sourceDir = devMode: dir:
    if devMode
    then toString dir
    else copyPathToStore dir;

  coordinateFor =
    { artifact, version
    , extension ? "jar"
    , classifier ? ""
    , group ? artifact
    , ...
    }: [ group artifact extension classifier version ];

  inRepo =
    { artifact, version
    , extension ? "jar"
    , classifier ? ""
    , group ? artifact
    , ...
    }: descriptor: { "${group}"."${artifact}"."${extension}"."${classifier}"."${version}" = descriptor; };

  repoSingleton =
    { artifact, version
    , extension ? "jar"
    , classifier ? ""
    , group ? artifact
    , dependencies ? []
    , dirs ? null
    , jar ? null
    , ...
    }@args: inRepo args {
      inherit dependencies dirs jar group artifact extension classifier version;
      coordinate = coordinateFor args;
    };

  dependencyList = dependencies:
    map (desc:
      if desc ? dwn.mvn then
        coordinateFor desc.dwn.mvn
      else if builtins.isList desc then
        desc
      else throw "Not a list ${toString desc}"
    ) dependencies;

  expandRepo = repo:
    mapRepoVals (desc: {
      dependencies = dependencyList desc.dependencies;
    }) repo;

  
  subProjectOverlay = {
    subProjects ? []
    , fixedVersions ? []
    , overlayRepo ? {}
    , closureRepo ? null
    , ...}:
      let result =
            lib.foldl mergeRepos {}
              (map (prj: let oprj = if prj ? overrideProject
                                    then (prj.overrideProject (_: {
                                      inherit closureRepo fixedVersions;
                                      overlayRepo = mergeRepos overlayRepo result;
                                    }))
                                    else prj;
                         in repoSingleton (oprj.dwn.mvn))
                subProjects);
      in result;

  subProjectFixedVersions = prjs:
    (map (prj: with prj.dwn;
      [group artifact extension classifier version])
      prjs);

  classpathFor = args: artifactClasspath args ++ dependencyClasspath args;

  artifactClasspath = args@{
    cljSourceDirs ? []
    , resourceDirs ? []
    , devMode ? false
    , ...
  }:   (map (sourceDir devMode) cljSourceDirs)
       ++ (map (sourceDir devMode) resourceDirs)
       ++ (classesFor args);

  dependencyClasspath = args@{ mavenRepos ? defaultMavenRepos , ... }:
    lib.concatLists (map (x: mvnResolve mavenRepos x) (expandDependencies args));

}
