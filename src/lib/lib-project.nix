self: super:

let
  inherit (self)
    lib copyPathToStore mergeRepos classesFor
    defaultMavenRepos mvnResolve expandDependencies
    dependencyClasspath mapRepoVals;
in {
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
    }@args: self.inRepo args {
      inherit dependencies dirs jar group artifact extension classifier version;
      coordinate = self.coordinateFor args;
    };

  dependencyList = dependencies:
    map (desc:
      if desc ? dwn.mvn then
        self.coordinateFor desc.dwn.mvn
      else if builtins.isList desc then
        desc
      else throw "Not a list ${toString desc}"
    ) dependencies;

  expandRepo = repo:
    mapRepoVals (desc: {
      dependencies = self.dependencyList desc.dependencies;
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
                         in self.repoSingleton (oprj.dwn.mvn))
                subProjects);
      in result;

  subProjectFixedVersions = prjs:
    (map (prj: with prj.dwn;
      [group artifact extension classifier version])
      prjs);

  classpathFor = args: self.artifactClasspath args ++ dependencyClasspath args;

  artifactClasspath = args@{
    cljSourceDirs ? []
    , resourceDirs ? []
    , devMode ? false
    , ...
  }:   (map (self.sourceDir devMode) cljSourceDirs)
       ++ (map (self.sourceDir devMode) resourceDirs)
       ++ (classesFor args);

  dependencyClasspath = args@{ mavenRepos ? defaultMavenRepos , ... }:
    lib.concatLists (map
      (x:
        let
          res = builtins.tryEval (mvnResolve mavenRepos x);
        in if res.success then res.value
           else lib.warn ("Didn't find dependency " + self.toEdn x + " please regenerate repository")
             [])
      (expandDependencies args));

}
