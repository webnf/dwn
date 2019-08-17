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

  subProjectOverlay = {
        subProjects ? []
      , fixedVersions ? []
      , overlayRepo ? {}
      , closureRepo ? null
      , ...}:
    let result =
    lib.foldl mergeRepos {}
      (map (prj: let oprj = (prj.overrideProject (_: {
                              inherit closureRepo fixedVersions;
                              overlayRepo = mergeRepos overlayRepo result;
                            }));
                     inherit (oprj.dwn) group artifact extension classifier version;
                 in {
                   "${group}"."${artifact}"."${extension}"."${classifier}"."${version}" = {
                     inherit (oprj.dwn) dependencies dirs group artifact coordinate;
                     inherit (oprj) overrideProject;
                   };
                 })
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
