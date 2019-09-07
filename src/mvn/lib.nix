self: super:

with self.lib;
{
  mvnResult = {dependencies, fixedVersions, overlayRepository, repositoryFile, ... }@args: {
    overlayRepository = foldl self.mergeRepos overlayRepository
      (map

        # ({ dwn, ... }:
        #   self.repoSingleton dwn.mvn)

        (pkg: self.repoSingleton
          (pkg.overrideConfig
            (cfg: recursiveUpdate cfg {
              dwn.mvn = {
                inherit repositoryFile;
                # fixedVersions = filter (d: self.coordinateFor args != self.coordinateFor d.dwn.mvn) fixedVersions;
              };
            })
          ).dwn.mvn)

        (filter (d: d ? dwn.mvn) (dependencies ++ fixedVersions)));
    dependencies = map
      (d: if d ? dwn.mvn
          then self.coordinateFor d.dwn.mvn
          else d)
      dependencies;
    fixedVersions = map
      (d: if d ? dwn.mvn
          then self.coordinateFor d.dwn.mvn
          else d)
      fixedVersions;
  };

  mergeRepos = recursiveUpdate;

  dependencyClasspath = args@{ mavenRepos ? defaultMavenRepos , ... }:
    concatLists (map
      (x:
        let
          res = builtins.tryEval (self.mvnResolve mavenRepos x);
        in if res.success then res.value
           else warn ("Didn't find dependency " + self.toEdn x + " please regenerate repository")
             [])
      (self.expandDependencies args));

  coordinateFor =
    { artifact, version
    , extension ? "jar"
    , classifier ? ""
    , group ? artifact
    , ...
    }: [ group artifact extension classifier version ];

  mavenCoordinate = pkg:
    if pkg ? dwn.mvn then
      self.coordinateFor pkg.dwn.mvn
    else if builtins.isList pkg then
      pkg
    else throw "Not a list ${toString pkg}";

  dependencyList = dependencies:
    map mavenCoordinate dependencies;

  expandRepo = repo:
    self.mapRepoVals (desc: {
      dependencies = self.dependencyList desc.dependencies;
    }) repo;

  mapRepoVals = f: repo:
    let mapVals = depth: vals:
      if depth > 0 then
        mapAttrs (_: v: mapVals (depth - 1) v) vals
      else
        f vals;
    in
      mapVals 5 repo;

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
                 if isNull dirs
                 then throw "Dirs for ${toString coordinate} not found"
                 else dirs
               else if "jar" == extension then
                 if ! isNull jar
                 then [ jar ]
                 else if isNull sha1 then
                   throw "Jar file for ${toString coordinate} not found"
                 else [ ((self.fetchurl {
                   name = "${name}-${version}.${extension}";
                   urls = self.mavenMirrors mavenRepos group name extension classifier baseVersion version;
                   inherit sha1;
                   # prevent nix-daemon from downloading maven artifacts from the nix cache
                 })  // { preferLocalBuild = true; }) ]
               else
                 throw "Unknown extension '${extension}'";
    in
      self.unwrapCoord resF coordinate;

  mavenMirrors = mavenRepos: group: name: extension: classifier: version: resolvedVersion: let
    dotToSlash = replaceStrings [ "." ] [ "/" ];
    tag = if classifier == "" then "" else "-" + classifier;
    mvnPath = baseUri: "${baseUri}/${dotToSlash group}/${name}/${version}/${name}-${resolvedVersion}${tag}.${extension}";
  in # builtins.trace "DOWNLOADING '${group}' '${name}' '${extension}' '${classifier}' '${version}' '${resolvedVersion}'"
       (map mvnPath mavenRepos);

  unwrapCoord = f: coordinate:
    let
      group = elemAt coordinate 0;
      name = elemAt coordinate 1;
      extension = elemAt coordinate 2;
      classifier = elemAt coordinate 3;
      version = elemAt coordinate 4;
    in
      f group name extension classifier version;

  repoSingleton =
    { artifact, version
    , extension ? "jar"
    , classifier ? ""
    , group ? artifact
    , dependencies ? []
    , dirs ? null
    , jar ? null
    , overlayRepository ? {}
    , ...
    }@args: self.mergeRepos overlayRepository (self.inRepo args {
      inherit dependencies dirs jar group artifact extension classifier version;
      coordinate = self.coordinateFor args;
    });

  inRepo =
    { artifact, version
    , extension ? "jar"
    , classifier ? ""
    , group ? artifact
    , ...
    }: descriptor: { "${group}"."${artifact}"."${extension}"."${classifier}"."${version}" = descriptor; };

}
