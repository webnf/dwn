{ lib, copyPathToStore
, mergeRepos
, classesFor
, defaultMavenRepos
, mvnResolve
, expandDependencies
, dependencyClasspath
}:

rec {
  sourceDir = devMode: dir:
    if devMode
    then toString dir
    else copyPathToStore dir;

  repoSingleton =
    { artifact, version
    , extension ? "jar"
    , classifier ? ""
    , group ? artifact
    , dependencies ? []
    , dirs ? null
    , jar ? null
    , ...
    }: {
      "${group}"."${artifact}"."${extension}"."${classifier}"."${version}" = {
        inherit dependencies dirs jar group artifact extension classifier version;
        coordinate = [ group artifact extension classifier version ];
      };
    };

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
    lib.concatLists (map (mvnResolve mavenRepos) (expandDependencies args));

}
