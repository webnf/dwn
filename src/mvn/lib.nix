self: super:

with builtins; with self.lib;
{

  mvnResult = {dependencies, fixedVersions, overlayRepository, repositoryFile, ... }@args:
    let
      filterOvr = filter (d: d ? overrideConfig);
    in
      {
        dependencies = self.mergeByType self.coordinateListT [ dependencies ];
        fixedVersions = self.mergeByType self.coordinateListT [ fixedVersions ];
        overlayRepository = self.mergeByType self.repoT
          ([ (self.repoSingleton args)
             overlayRepository ]
          ++
          (map
            (x: x.dwn.mvn.overlayRepository)
            (filterOvr (dependencies ++ fixedVersions))));
      };

  dependencyClasspath = args@{ mavenRepos ? defaultMavenRepos , ... }:
    concatLists (map
      (x:
        # self.mvnResolve mavenRepos (self.unpackEdnDep x)
        let
          res = builtins.tryEval (self.mvnResolve mavenRepos (self.unpackEdnDep x));
        in if res.success then res.value
           else warn ("Didn't find dependency " + self.toEdn x + " please regenerate repository")
             []
      )
      (self.expandDependencies args));

  # FIXME remove
  coordinateFor =
    { artifact, version
    , extension ? "jar"
    , classifier ? ""
    , group ? artifact
    , ...
    }: [ group artifact extension classifier version ];

  # FIXME remove
  mavenCoordinate = pkg:
    if pkg ? dwn.mvn then
      self.coordinateFor pkg.dwn.mvn
    else if builtins.isList pkg then
      pkg
    else throw "Not a list ${toString pkg}";

  # FIXME remove
  dependencyList = dependencies:
    map mavenCoordinate dependencies;

  # FIXME remove
  expandRepo = repo:
    self.mapRepoVals (desc: {
      dependencies = self.dependencyList desc.dependencies;
    }) repo;

  # FIXME remove
  mapRepoVals = f: repo:
    let mapVals = depth: vals:
      if depth > 0 then
        mapAttrs (_: v: mapVals (depth - 1) v) vals
      else
        f vals;
    in
      mapVals 5 repo;

  # FIXME remove by reworking aether and expander
  unpackEdnDep = 
    { coordinate ? null
    , sha1 ? null
    , dirs ? null
    , jar ? null
    , ... }@args:
    let resF = group: artifact: extension: classifier: version:
          if isNull coordinate then args
          else { inherit group artifact extension classifier version; } // args;
    in
      self.unwrapCoord resF coordinate;
  
  mvnResolve =
    mavenRepos:
    { base-version ? null
    , group, artifact, extension, classifier, version
    , sha1 ? null
    , dirs ? null
    , jar ? null
    , ... }@args:
    let
      baseVersion = if isNull base-version then version else base-version;
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
          name = "${artifact}-${version}.${extension}";
          urls = self.mavenMirrors mavenRepos group artifact extension classifier baseVersion version;
          inherit sha1;
          # prevent nix-daemon from downloading maven artifacts from the nix cache
        })  // { preferLocalBuild = true; }) ]
      else
        throw (trace args "Unknown extension in '${toString extension}'");

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
    , extension
    , classifier
    , group
    , dependencies
    , dirs
    , jar
    , fixedVersions
    , ...
    }@args:
    self.inRepo args {
      inherit dirs jar group artifact extension classifier version;
      dependencies = self.mergeByType self.coordinateListT [ dependencies ];
      fixed-versions = self.mergeByType self.coordinateListT [ fixedVersions ];
    };
  
  inRepo =
    { artifact, version
    , extension ? "jar"
    , classifier ? ""
    , group ? artifact
    , ...
    }: descriptor: { "${group}"."${artifact}"."${extension}"."${classifier}"."${version}" = descriptor; };

  dependencyT = mkOptionType rec {
    name = "maven-dependency";
    description = "maven dependency";
    ## TODO syntax check
    check = v: isList v || isAttrs v;
    merge = mergeEqualOption;
  };

  plainDependencyT = mkOptionType rec {
    name = "maven-list-dependency";
    description = "plain maven coordinate";
    ## TODO syntax check
    check = v: isList v;
    merge = mergeEqualOption;
  };

  coordinateListT =
    with types;
    self.typeMap
      (listOf
        (coercedTo
          self.dependencyT
          (d: self.coordinateFor (d.dwn.mvn))
          self.plainDependencyT))
      unique
      (listOf self.plainDependencyT);

  repoCoordT = with types; let
    inherit (self) plainDependencyT;
  in
    submodule {
      options = {
        group = mkOption {
          type = types.str;
        };
        artifact = mkOption {
          type = types.str;
        };
        version = mkOption {
          type = types.str;
        };
        base-version = mkOption {
          default = null;
          type = nullOr types.str;
        };
        extension = mkOption {
          type = types.str;
        };
        classifier = mkOption {
          type = types.str;
        };
        dependencies = mkOption {
          type = types.listOf plainDependencyT;
        };
        fixed-versions = mkOption {
          type = types.listOf plainDependencyT;
        };
        sha1 = mkOption {
          default = null;
          type = nullOr str;
        };
        jar = mkOption {
          default = null;
          type = nullOr self.pathT;
        };
        dirs = mkOption {
          default = [];
          type = listOf self.pathT;
        };
      };
    };
  
  repoT = with types; let
    depType = subT:
      types.attrsOf subT;
  in
    depType
      (depType
        (depType
          (depType
            (depType
              self.repoCoordT))));

}
