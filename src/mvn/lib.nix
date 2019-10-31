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
        default = (self.repoL.getDefault
          config.repository config (warn "Not found in repo ${config.group}:${config.artifact}:${config.version}" [])
        ).dependencies or [];
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
      scope = mkOption {
        default = "compile";
        type = str;
        description = ''
          The scope for this project to be included in
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
                  then warn "No dirs for [ ${config.group} ${config.artifact} ${config.version} ]" [ ]
                  else [ ];
        type = self.pathsT;
      };
      jar = mkOption {
        default =
          if config.extension == "jar"
          then with config;
            if isNull sha1
            then warn "No jar file / sha1 for [ ${group} ${artifact} ${version} ]" null
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
      passthru = self.internalDefault {
        pin = { inherit (config) group artifact; };
        coordinate = {
          inherit (config) extension classifier version;
          dependencies = map (d: d.config.passthru) config.dependencies;
          fixedVersions = map (d: d.config.passthru) config.fixedVersions;
          providedVersions = map (d: d.config.passthru) config.providedVersions;
        };
        qualifier = { inherit (config) scope exclusions; };
        metadata = { inherit (config) sha1 repository; };
        classpathEntry = config.${config.extension};
      };
    };

    # linkageFor = config: lself: lsuper:
    #   let res = tryEval (self.mvn.linkageFor' config lself lsuper); in
    #   if res.success
    #   then res.value
    #   else warn "Linking ${config.group}:${config.artifact}:${config.version} failed: ${toString res.value}" lsuper;

    linkageFor = config: lself: lsuper:
      if self.mvn.versionOlder
        config
        (self.pinL.getDefault lsuper.providedVersionMap config config)
      then lsuper
      else if self.mvn.excluded lsuper config
      then lsuper
      else let
        resolvedVersionMap = self.pinL.set lsuper.resolvedVersionMap config config;
        fixedVersionMap = self.mvn.mergeFixedVersions
          lsuper.fixedVersionMap (self.mvn.pinMap config.fixedVersions);
        providedVersionMap = self.pinL.set lsuper.providedVersionMap config config;
        currentResolved = self.pinL.get lsuper.resolvedVersionMap config;
      in if self.pinL.has lsuper.providedVersionMap config
         then lsuper // {
           inherit resolvedVersionMap;
         }
         else if self.pinL.has lsuper.resolvedVersionMap config
                 && self.mvn.versionOlder config currentResolved
         then lsuper
         else foldl'
           (lsuper: dep:
             let res = self.mvn.linkageFor dep lself lsuper; in
             res // {
               path = [ (self.pinL.get lself.resolvedVersionMap dep) ] ++ res.path;
             })
           (lsuper // {
             inherit resolvedVersionMap fixedVersionMap providedVersionMap;
           })
           (reverseList config.dependencies);

    linkage = cfg: fix
      (lself: self.mvn.linkageFor cfg lself {
        path = [];
        exclusions = [];
        fixedVersionMap = {};
        providedVersionMap = {};
        resolvedVersionMap = {};
      });

    dependencyPath = cfg: (self.mvn.linkage cfg).path;

    compilePath = cfg:
      let lr = self.mvn.linkage cfg; in
      (fix (lself: self.mvn.linkageFor cfg lself lr // {
        fixedVersionMap = self.mvn.mergePins lr.fixedVersionMap lr.providedVersionMap;
      })).path;

    excluded = { exclusions, ... }: { group, artifact, ... }:
      ! isNull
        (findFirst (e: dep.group == e.group && dep.artifact == e.artifact)
          null exclusions);

    versionOlder = cfg1: cfg2:
      self.lib.versionOlder cfg1.version cfg2.version;

    hydrateDependency = dep: mvn:
      if dep ? extension && dep ? ${dep.extension}
      then dep
      else let
        result = self.mergeByType
          (submodule {
            options = self.mvn.optionsFor result;
          })
          [ mvn dep ];
      in result;

    pinMap = coords: foldl' (s: e: self.pinL.set s e e) {} coords;

    mergePins = pm1: pm2:
      foldAttrs
        (pm: g: as:
          pm // { ${g} = pm.${g} or {} // as; })
        pm1 pm2;

    mergeFixedVersions =
      self.mergeAttrsWith
        (group: self.mergeAttrsWith
          (artifact: v1: v2:
            if v1 == v2
            then v1
            else throw "Incompatible fixed versions for ${group} ${artifact}"));

    dependencyClasspath = dependencies:
      concatLists (map
        (d: let ext = d.extension; in
            if ext == "jar"
            then if isNull d.jar
                 then []
                 else [ d.jar ]
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
      check = m: isAttrs m && m ? artifact;
      merge = mergeEqualOption;
    };

    drvDependencyT = mkOptionType {
      name = "derivation-maven-dependency";
      description = "DWN maven dependency";
      check = d: isAttrs d && d ? dwn.mvn;
      merge = mergeEqualOption;
    };

    dependencyT = either
      (coercedTo self.mvn.lstDependencyT fromList self.mvn.mapDependencyT)
      (coercedTo self.mvn.drvDependencyT (d: d.dwn.mvn) self.mvn.mapDependencyT);

    projectDependencyT = config:
      self.typeMap
        self.mvn.dependencyT
        (d: self.mvn.hydrateDependency d { inherit (config) repository; })
        self.mvn.mapDependencyT;

    mirrorsFor = mavenRepos: group: name: extension: classifier: version: resolvedVersion: let
      dotToSlash = replaceStrings [ "." ] [ "/" ];
      tag = if classifier == "" then "" else "-" + classifier;
      mvnPath = baseUri: "${baseUri}/${dotToSlash group}/${name}/${version}/${name}-${resolvedVersion}${tag}.${extension}";
    in # builtins.trace "DOWNLOADING '${group}' '${name}' '${extension}' '${classifier}' '${version}' '${resolvedVersion}'"
      (map mvnPath mavenRepos);

  };

  keyedListFor = type: keyFn: merge: let
    uniqueFor = keyFn: merge: loc: list:
      if list == [] then
        []
      else
        let
          x = head list;
          t = tail list;
          kx = keyFn x;
          fm = y: kx == keyFn y;

          m = filter fm t;
          o = remove fm t;
        in merge loc m ++ uniqueFor keyFn merge loc o;
    listT = listOf type;
  in mkOptionType rec {
    name = "keyed-list";
    description = "Keyed list";
    check = listT.check;
    merge = loc: defs:
      uniqueFor keyFn merge loc (listT.merge loc defs);
    functor = (defaultFunctor name) // { wrapped = listT; };
  };
}
