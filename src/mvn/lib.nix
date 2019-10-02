self: super:

with builtins;
with self.lib;
let
  completeInfo =
    { group ? artifact
    , version ? "*"
    , classifier ? ""
    , extension ? "jar"
    , scope ? "compile"
    , exclusions ? []
    , dependencies ? []
    , fixedVersions ? {}
    , artifact
    }: {
      inherit group artifact version classifier extension fixedVersions scope;
      exclusions = unique (map coordinateInfo exclusions);
      dependencies = unique (map coordinateInfo dependencies);
    };
  completeDependency =
    { group ? artifact
    , artifact
    , version
    , classifier ? ""
    , extension ? "jar"
    , scope ? "compile"
    , exclusions ? []
    , dependencies ? []
    , fixedVersions ? {}
    }: {
      inherit group artifact version classifier extension scope;
      exclusions = unique (map (coordinateInfo2 completeExclusion) exclusions);
      dependencies = unique (map (coordinateInfo2 completeDependency) dependencies);
      fixedVersions = unique (map );
    };

  coordinateInfo = o:
    completeInfo
      (if isAttrs o then o
       else if isList o then fromList o
       else throw "Not attrs or list: ${toString o}");
  coordinateInfo2 = completeInfo: o:
    if isList o then {
      dwn.mvn = completeInfo2 (fromList o);
    }
    else if ! o ? dwn.mvn then
      throw "Not a dwn project or maven coordinate ${toString o}"
    else o;
  fromList = lst:
    let l = length lst;
        e = (elemAt lst (l - 1)); in
    if l > 1 && isAttrs e then
      (fromList (take (l - 1) lst)) // e
    else if 1 == l then
      throw "Don't know version of [${toString lst}]"
    else if 2 == l then {
        group = elemAt lst 0;
        artifact = elemAt lst 0;
        version = elemAt lst 1;
    } else if 3 == l then {
      group = elemAt lst 0;
      artifact = elemAt lst 1;
      version = elemAt lst 2;
    } else if 4 == l then {
      group = elemAt lst 0;
      artifact = elemAt lst 1;
      classifier = elemAt lst 2;
      version = elemAt lst 3;
    } else if 5 == l then {
      group = elemAt lst 0;
      artifact = elemAt lst 1;
      extension = elemAt lst 2;
      classifier = elemAt lst 3;
      version = elemAt lst 4;
    } else throw "Invalid list length ${toString l}";
in {

  inherit coordinateInfo;
  
  mvnResult = overrideConfig: {dependencies, fixedVersions, overlayRepository, repositoryFile, ... }@args:
    let
      filterOvr = filter (d: d ? overrideConfig);
    in
      {
        dependencies = self.mergeByType self.coordinateListT [ dependencies ];
        fixedVersions = self.mergeByType self.coordinateListT [ fixedVersions ];
        overlayRepository = self.mergeByType self.repoT
          ([ (self.singletonRepo overrideConfig args)
             overlayRepository ]
          ++
          (map
            (x: x.dwn.mvn.overlayRepository)
            (filterOvr (dependencies ++ fixedVersions))));
      };

  mvnResult2 = overrideConfig: cfg: rec {
    dependencies = map (coordinateInfo2 completeDependency) cfg.dependencies;
    fixedVersions =
      unique
        (concatLists
          ((map (coordinateInfo2 completeFixedVersions) cfg.fixedVersions)
           ++ (map (d: d.mvnResult2.fixedVersions) dependencies)));
    exclusions = map (coordinateInfo2 completeExclusions) cfg.exclusions;

    dependencyClasspath = [];
  };

  mvn = {
    pinMap = coords: foldl' (s: e: self.pinL.set s e.dwn.mvn e) {} coords;
    mergeFixedVersions =
      self.mergeAttrsWith
        (group: self.mergeAttrsWith
          (artifact: v1: v2:
            if v1 == v2
            then v1
            else throw "Incompatible fixed versions for ${group} ${artifact}"));
    updateResolvedVersions = rvMap: mcfg: e:
      if ! self.pinL.has rvMap mcfg
         || versionOlder
           (self.pinL.get rvMap mcfg).dwn.mvn.version
           mcfg.version
      then self.pinL.set rvMap mcfg e
      else rvMap;
    resolve = d:
      fix ((flip d.mvnResult3) {
        exclusions = [];
        dependencies = [];
        fixedVersionMap = {};
        providedVersionMap = {};
        resolvedVersionMap = {};
      });
    dependencyClasspath = dependencies:
      concatLists (map
        (d: let ext = d.dwn.mvn.extension; in
            if ext == "jar"
            then [ d.dwn.mvn.jar ]
            else if ext == "dirs"
            then d.dwn.mvn.dirs
            else throw "Unknown extension ${ext}")
        dependencies);
    ## FIXME into module
    pimpConfig = cfg:
      let
        repo = importJSON cfg.dwn.mvn.repositoryFile;
        inflateDep = d: if isList d
                        then let
                          mvn = fromList d;
                          dsc = self.repoL.get repo
                            (self.build {
                              mvn = mvn // {
                                inherit (cfg.dwn.mvn) repositoryFile;
                                extension = "jar";
                              };
                            }).dwn.mvn;
                        in
                          self.build {
                            mvn = mvn // {
                              inherit (dsc) sha1;
                              dependencies = map inflateDep (dsc.dependencies or []);
                            };
                          }
                        else d;
      in
      cfg // {
        dwn = cfg.dwn // {
          mvn = cfg.dwn.mvn // {
            dependencies = map
              inflateDep
              cfg.dwn.mvn.dependencies;
          };
        };
      };
  };

  reduceAttrs = f: s: a:
    foldl' (s: n: f s n (getAttr n a))
      s (attrNames a);

  mergeAttrsWith = mf: a1: a2:
    self.reduceAttrs
      (a: n: v:
        setAttr a n
          (if hasAttr n a
           then (mf n (getAttr n a) v)
           else v))
      a1 a2;
  
  mvnResult3 = cfg: rself: rsuper: let
    mcfg = cfg.dwn.mvn;
    resolvedVersionMap = self.mvn.updateResolvedVersions rsuper.resolvedVersionMap mcfg cfg.result;
  in
    if self.pinL.has rsuper.providedVersionMap mcfg
    then {
      inherit (rsuper) dependencies fixedVersionMap providedVersionMap;
      inherit resolvedVersionMap;
    }
    else let
      providedVersionMap = self.pinL.set rsuper.providedVersionMap mcfg cfg.result;
      fixedVersionMap = self.mvn.mergeFixedVersions rsuper.fixedVersionMap (self.mvn.pinMap mcfg.fixedVersions);
      exclusions = unique (rsuper.exclusions ++ mcfg.exclusions);
      dresult = foldl'
        (s: d: let r = d.mvnResult3 rself s; in
               r // { dependencies =
                        [(self.pinL.getDefault r.fixedVersionMap d.dwn.mvn
                          (self.pinL.get r.resolvedVersionMap d.dwn.mvn))]
                        ++ r.dependencies; } )
        {
          inherit (rsuper) dependencies;
          inherit providedVersionMap fixedVersionMap resolvedVersionMap exclusions;
        }
        (reverseList mcfg.dependencies);
    in {
      # dependencies =
      #   [ (self.pinL.getDefault rself.fixedVersionMap mcfg (self.pinL.get rself.resolvedVersionMap mcfg)) ]
      #   ++ dresult.dependencies;
      fixedVersionMap = self.mvn.mergeFixedVersions rsuper.fixedVersionMap (self.mvn.pinMap mcfg.fixedVersions);
      inherit (dresult) providedVersionMap resolvedVersionMap dependencies;
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

  dependencyClasspath2 = cfg:
    concatLists (map
      (x:
        let
          res = builtins.tryEval (self.mvnResolve cfg.dwn.mvn.repos x);
        in if res.success then res.value
           else warn ("Didn't find dependency " + self.toEdn x + " please regenerate repository")
             []
      )
      (self.expandDependencies2 cfg));

  dependencyClasspath3 = cfg:
    concatLists (map
      (x:
        let
          res = builtins.tryEval (self.mvnResolve cfg.dwn.mvn.repos x);
        in if res.success then res.value
           else warn ("Didn't find dependency " + self.toEdn x + " please regenerate repository")
             []
      )
      (self.expandDependencies3 cfg));

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
        then throw "Dirs for ${group} ${artifact} ${version} not found"
        else dirs
      else if "jar" == extension then
        if ! isNull jar
        then [ jar ]
        else if isNull sha1 then
          throw "Jar file for ${group} ${artifact} ${version} not found"
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

  singletonRepo =
    overrideConfig:
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
      instantiate = { fixedVersions, overlayRepository, repositoryFile }:
        overrideConfig (cfg:
          cfg // {
            dwn = cfg.dwn // {
              mvn = cfg.dwn.mvn // {
                inherit fixedVersions overlayRepository repositoryFile;
              };
            };
          });
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
          default = null;
          type = nullOr types.str;
        };
        artifact = mkOption {
          default = null;
          type = nullOr types.str;
        };
        version = mkOption {
          default = null;
          type = nullOr types.str;
        };
        base-version = mkOption {
          default = null;
          type = nullOr types.str;
        };
        extension = mkOption {
          default = null;
          type = nullOr types.str;
        };
        classifier = mkOption {
          default = null;
          type = nullOr types.str;
        };
        dependencies = mkOption {
          default = [];
          type = types.listOf plainDependencyT;
        };
        fixed-versions = mkOption {
          default = [];
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
        instantiate = mkOption {
          default = null;
          type = nullOr (mkOptionType {
            name = "instantiation-fn";
            merge = loc: defs:
              ## equality should be guaranteed by
              ## checks on sha1 / jar / dirs
              (head defs).value;
          });
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
