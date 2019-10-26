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
    else if 1 == l then {
        group = elemAt lst 0;
        artifact = elemAt lst 0;
        version = "0";
    }
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
    optionsFor = config: let depT = listOf self.mvn.dependencyT; in {
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
        default = "jar";
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
        default = if config.extension == "dirs"
                  then throw "No dirs for [ ${config.group} ${config.artifact} ${config.version} ]"
                  else [ ];
        type = self.pathsT;
      };
      jar = mkOption {
        default =
          if config.extension == "jar"
          then with config;
            if isNull sha1
            then throw "No jar file / sha1 for [ ${group} ${artifact} ${version} ]"
            else
              (self.fetchurl ( {
                name = "${group}__${artifact}__${version}.${extension}";
                urls = self.mvn.mirrorsFor repos group artifact extension classifier baseVersion version;
                inherit sha1;
              }))
              # prevent nix-daemon from downloading maven artifacts from the nix cache
              // { preferLocalBuild = true; }
          else null;
        type = nullOr self.pathT;
      };
      sha1 = mkOption {
        default =
          if config.extension == "jar"
          then (
            self.repoL.getDefault
              config.repository config
              { sha1 = null; } # (throw "No sha1 for [ ${config.group} ${config.artifact} ${config.version} ]")
          ).sha1
          else null;
        type = nullOr str;
      };
      repository = mkOption {
        default = {};
        type = self.mvn.repoT;
      };

      overrideLinkage = self.internalDefault (_: with config; throw "No default linkage for [ ${group} ${artifact} ${version} ]"); #(linkage: self.mvn.optionsFor (config // { inherit linkage; }));

      linkage = self.internalDefault {
        path = [];
        exclusions = [];
        fixedVersionMap = {};
        providedVersionMap = {};
        resolvedVersionMap = {};
      };

      resultLinkage = self.internalDefault (let
        resolvedVersionMap = self.mvn.updateResolvedVersions config.linkage.resolvedVersionMap config;
        fixedVersionMap = self.mvn.mergeFixedVersions config.linkage.fixedVersionMap (self.mvn.pinMap config.fixedVersions);
        providedVersionMap = self.pinL.set config.linkage.providedVersionMap config config;
      in
        if self.pinL.has config.linkage.providedVersionMap config
        then {
          inherit (config.linkage) fixedVersionMap providedVersionMap exclusions path;
          inherit resolvedVersionMap;
        }
        else
          let
            result = foldl'
              (linkage: pd:
                let
                  d = self.mvn.hydrateDependency pd {
                    inherit (config) repository;
                    inherit linkage;
                  };
                in
                  if self.mvn.dependencyFilter linkage.providedVersionMap linkage.exclusions d
                  then d.resultLinkage // {
                    path = [
                      (self.pinL.getDefault
                        result.fixedVersionMap d
                        (self.pinL.getDefault
                          result.resolvedVersionMap d
                          (throw (trace result.resolvedVersionMap "Cannot find ${config.group} ${config.artifact}"))))
                    ] ++ d.resultLinkage.path;
                  }
                  else linkage)
              {
                inherit resolvedVersionMap fixedVersionMap providedVersionMap;
                inherit (config.linkage) path;
                exclusions = unique (config.linkage.exclusions ++ config.exclusions);
              }
              (reverseList config.dependencies);
          in {
            inherit (config.linkage) exclusions;
            inherit (result) resolvedVersionMap providedVersionMap fixedVersionMap path;
          });

    };

    dependencyFilter = providedVersionMap: exclusions: dep:
      ! self.pinL.has providedVersionMap dep
      && isNull
        (findFirst (e: dep.group == e.group && dep.artifact == e.artifact)
          null exclusions);

    hydrateDependency = dep: mvn:
      if dep ? overrideLinkage
      then dep.overrideLinkage mvn.linkage
      else let
        result = self.mergeByType (submodule { options = self.mvn.optionsFor result; }) [
          mvn
          {
            dependencies =
              (self.repoL.getDefault
                result.repository result (throw "No found in repo ${group}/${artifact}")
              ).dependencies or [];
            overrideLinkage = linkage:
              if mvn.linkage == linkage then result
              else self.mvn.hydrateDependency dep (mvn // { inherit linkage; });
          }
          dep
        ];
      in result;

    hydrateDependency0 = config: dep:
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
