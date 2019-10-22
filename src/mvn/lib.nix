self: super:

with builtins;
with self.lib;
with types;
let
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

  mvn = {
    optionsFor = config: let depT = listOf (self.mvn.projectDependencyT config); in {
      group = mkOption {
        type = str;
        default = config.artifact;
        description = "Maven group";
      };
      artifact = mkOption {
        type = str;
        description = "Maven artifact";
      };
      version = mkOption {
        type = str;
        description = "Maven version";
      };
      baseVersion = mkOption {
        default = config.version;
        type = str;
        description = "Base (path) maven version";
      };
      extension = mkOption {
        type = str;
        default = if ! isNull config.sha1 then "jar" else "dirs";
        description = "Maven packaging extension";
      };
      classifier = mkOption {
        type = str;
        default = "";
        description = "Maven classifier";
      };
      repos = mkOption {
        default = [ http://repo1.maven.org/maven2
                    https://clojars.org/repo ];
        type = listOf self.urlT;
        description = ''
        Maven repositories
      '';
      };
      dependencies = mkOption {
        default = [];
        type = depT;
        description = ''
        Maven dependencies.
      '';
      };
      exclusions = mkOption {
        default = [];
        ## FIXME coordinate w/o version
        type = depT;
        description = ''
        Maven exclusions
      '';
      };
      providedVersions = mkOption {
        default = [];
        type = depT;
        description = ''
        Dependencies, that are already on the classpath. Either from a container, or previous dependencies.
      '';
      };
      fixedVersions = mkOption {
        default = [];
        type = depT;
        description = ''
        Override versions from dependencies (transitive).
        As opposed to `providedVersions`, this will include a dependency, but at the pinned version.
      '';
      };
      dirs = mkOption {
        default = throw "No dirs for [ ${config.group} ${config.artifact} ${config.version} ]";
        type = self.pathsT;
      };
      jar = mkOption {
        default = with config;
          if isNull sha1
          then throw "No jar file / sha1 for [ ${group} ${artifact} ${version} ]"
          else
            (self.fetchurl ( {
              name = "${group}__${artifact}__${version}.${extension}";
              urls = self.mvn.mirrorsFor repos group artifact extension classifier baseVersion version;
              inherit sha1;
            }))
            # prevent nix-daemon from downloading maven artifacts from the nix cache
            // { preferLocalBuild = true; };
        type = self.pathT;
      };
      sha1 = mkOption {
        default = (self.repoL.getDefault config.repository config { sha1 = null; }).sha1;
        type = nullOr str;
      };
      repository = mkOption {
        default = {};
        type = self.mvn.repoT;
      };
      linkAsDependency = mkOption {
        default = self.mvn.linkAsDependencyFor config;
        type = unspecified;
        internal = true;
      };
    };

    linkAsDependencyFor = config: rself: rsuper: let
      resolvedVersionMap = self.mvn.updateResolvedVersions rsuper.resolvedVersionMap config;
    in
      if self.pinL.has rsuper.providedVersionMap config
      then {
        inherit (rsuper) dependencies fixedVersionMap providedVersionMap;
        inherit resolvedVersionMap;
      }
      else let
        providedVersionMap = self.pinL.set rsuper.providedVersionMap config config;
        fixedVersionMap = self.mvn.mergeFixedVersions rsuper.fixedVersionMap (self.mvn.pinMap config.fixedVersions);
        exclusions = unique (rsuper.exclusions ++ config.exclusions);
        dresult = foldl'
          (s: d: let r = d.linkAsDependency rself s; in
                 r // { dependencies =
                          [(self.pinL.getDefault r.fixedVersionMap d
                            (self.pinL.get r.resolvedVersionMap d))]
                          ++ r.dependencies; } )
          {
            inherit (rsuper) dependencies;
            inherit providedVersionMap fixedVersionMap resolvedVersionMap exclusions;
          }
          (reverseList config.dependencies);
      in {
        # dependencies =
        #   [ (self.pinL.getDefault rself.fixedVersionMap config (self.pinL.get rself.resolvedVersionMap config)) ]
        #   ++ dresult.dependencies;
        fixedVersionMap = self.mvn.mergeFixedVersions rsuper.fixedVersionMap (self.mvn.pinMap config.fixedVersions);
        inherit (dresult) providedVersionMap resolvedVersionMap dependencies;
      };

    hydrateDependency = config: dep:
      if dep ? linkAsDependency
      then dep
      else let
        result = self.mergeByType (submodule { options = self.mvn.optionsFor result; }) [
          (self.selectAttrs ["repos" "repository" "exclusions" "providedVersions" "fixedVersions"] config)
          dep
        ];
      in result;

    pinMap = coords: foldl' (s: e: self.pinL.set s e e) {} coords;

    mergeFixedVersions =
      self.mergeAttrsWith
        (group: self.mergeAttrsWith
          (artifact: v1: v2:
            if v1 == v2
            then v1
            else throw "Incompatible fixed versions for ${group} ${artifact}"));

    updateResolvedVersions = rvMap: mcfg:
      if ! self.pinL.has rvMap mcfg
         || versionOlder
           (self.pinL.get rvMap mcfg).version
           mcfg.version
      then self.pinL.set rvMap mcfg mcfg
      else rvMap;

    resolve = d:
      fix ((flip d.linkAsDependency) {
        exclusions = [];
        dependencies = [];
        fixedVersionMap = {};
        providedVersionMap = {};
        resolvedVersionMap = {};
      });

    dependencyClasspath = dependencies:
      concatLists (map
        (d: let ext = d.extension; in
            if ext == "jar"
            then [ d.jar ]
            else if ext == "dirs"
            then d.dirs
            else throw "Unknown extension ${ext}")
        dependencies);

    repoT =
      attrsOf
        (attrsOf
          (attrsOf
            (attrsOf
              (attrsOf
                # partial mvn options
                unspecified))));

    mapRepo = f: repo:
      mapAttrs
        (group: arts:
          mapAttrs
            (artifact: exts:
              mapAttrs
                (extension: clss:
                  mapAttrs
                    (classifier: vrss:
                      mapAttrs
                        (version: desc:
                          f group artifact extension classifier version desc)
                        vrss)
                    clss)
                exts)
            arts)
        repo;

    lstDependencyT = mkOptionType {
      name = "list-maven-dependency";
      description = "List maven dependency";
      check = isList;
      merge = mergeEqualOption;
    };

    mapDependencyT = mkOptionType {
      name = "map-maven-dependency";
      description = "Map maven dependency";
      check = m: isAttrs m && ! isDerivation m;
      merge = mergeEqualOption;
    };

    drvDependencyT = mkOptionType {
      name = "derivation-maven-dependency";
      description = "DWN maven dependency";
      check = d: isDerivation d && d ? dwn.mvn;
      merge = mergeEqualOption;
    };

    dependencyT = either
      (coercedTo self.mvn.lstDependencyT fromList self.mvn.mapDependencyT)
      (coercedTo self.mvn.drvDependencyT (d: d.dwn.mvn) self.mvn.mapDependencyT);

    projectDependencyT = config:
      self.typeMap
        self.mvn.dependencyT
        (self.mvn.hydrateDependency config)
        self.mvn.mapDependencyT;

    mirrorsFor = mavenRepos: group: name: extension: classifier: version: resolvedVersion: let
      dotToSlash = replaceStrings [ "." ] [ "/" ];
      tag = if classifier == "" then "" else "-" + classifier;
      mvnPath = baseUri: "${baseUri}/${dotToSlash group}/${name}/${version}/${name}-${resolvedVersion}${tag}.${extension}";
    in # builtins.trace "DOWNLOADING '${group}' '${name}' '${extension}' '${classifier}' '${version}' '${resolvedVersion}'"
      (map mvnPath mavenRepos);

  };

  # dependencyClasspath = args@{ mavenRepos ? defaultMavenRepos , ... }:
  #   concatLists (map
  #     (x:
  #       # self.mvnResolve mavenRepos (self.unpackEdnDep x)
  #       let
  #         res = builtins.tryEval (self.mvnResolve mavenRepos (self.unpackEdnDep x));
  #       in if res.success then res.value
  #          else warn ("Didn't find dependency " + self.toEdn x + " please regenerate repository")
  #            []
  #     )
  #     (self.expandDependencies args));

}
