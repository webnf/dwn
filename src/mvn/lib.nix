self: super:

with builtins;
with self.lib;
with self.mvn;
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

  mvn = (super.mvn or {}) // {
    nameFor = config:
      "${config.group}__${config.artifact}__${config.version}${
        (optionalString ((config.classifier or "") != "") "__${config.classifier}")
      }.${config.extension}";
    optionsFor = config: let
      depT = listOf (self.mvn.projectDependencyT config);
      error = self.errorDerivation "error__${self.mvn.nameFor config}";
    in {
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
        # default = (self.repoL.getDefault
        #   config.repository config
        #   [(error "Not found in repo")]
        # ).dependencies or [];
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
                  then [(error "No dirs")]
                  else [ ];
        type = self.pathsT;
      };
      jar = mkOption {
        default =
          if config.extension == "jar"
          then with config;
            if isNull sha1
            then error "No jar file / sha1"
            else
              (self.fetchurl ( {
                name = "${group}__${artifact}__${version}.${extension}";
                urls = self.mvn.mirrorsFor config;
                inherit sha1;
              }))
              # prevent nix-daemon from downloading maven artifacts from the nix cache
              // { preferLocalBuild = true; }
          else null;
        type = nullOr self.pathT;
      };
      sha1 = mkOption {
        default = null;
          # if config.extension == "jar"
          # then (
          #   self.repoL.getDefault
          #     config.repository config
          #     { sha1 = null; } # (throw "No sha1 for [ ${config.group} ${config.artifact} ${config.version} ]")
          # ).sha1 or null
          # else null;
        type = nullOr str;
      };
      overlay = (self.internalDefault false);
      repository = mkOption {
        default = {};
        type = self.mvn.repoT;
      };
      override = self.internalDefault (config2:
        optionsFor (config // config2)
      );
    };

    # linkageFor = config: lself: lsuper:
    #   let res = tryEval (self.mvn.linkageFor' config lself lsuper); in
    #   if res.success
    #   then res.value
    #   else warn "Linking ${config.group}:${config.artifact}:${config.version} failed: ${toString res.value}" lsuper;

    overlayFor = config: osuper:
      if self.repoL.has osuper config
      then osuper
        ## FIXME
        # if config == self.repoL.get osuper config
        #    then osuper
        #    else throw "Conflicting overlay entries ${self.mvn.nameFor config}"
      else let
        scanDeps = config.dependencies ++ config.fixedVersions ++ config.providedVersions;
      in foldl'
        (osuper: dep: self.mvn.overlayFor dep osuper)
        (self.repoL.set osuper config config)
        (filter
          (d: d ? overlayRepository)
          scanDeps);

    linkagePass = deps: lsuper:
      foldl
        (lsuper: dep:
          let res = self.mvn.linkageFor dep lsuper; in
          if self.pinL.has lsuper.providedVersionMap dep
          then res
          else res // {
            path = [
              (self.pinL.getDefault
                lsuper.fixedVersionMap dep
                (self.pinL.get
                  lsuper.resolvedVersionMap dep))
            ] ++ res.path;
          })
        lsuper deps;

    linkageFor = config: lsuper:
      let
        currentResolved = self.pinL.get lsuper.resolvedVersionMap config;
        wouldProvide =
          ! self.pinL.has lsuper.fixedVersionMap config
          && (! self.pinL.has lsuper.resolvedVersionMap config
              || self.mvn.versionOlder currentResolved config
              || (config.version == currentResolved.version
                  && # (if config.overlay && currentResolved.overlay ## && config != currentResolved
                  #     && config.${config.extension} != currentResolved.${currentResolved.extension}
                  #  then throw "Conflicting overlays ${self.mvn.nameFor config} ${self.mvn.nameFor currentResolved}"
                  #  else config.overlay)
                  config.overlay));
        hasProvided = self.pinL.has lsuper.providedVersionMap config;
        rconfig = if wouldProvide then config
                  else self.pinL.getDefault
                    lsuper.fixedVersionMap config
                    (self.pinL.get
                      lsuper.resolvedVersionMap config);
        rdeps = reverseList rconfig.dependencies;

        providedVersionMap = self.pinL.set lsuper.providedVersionMap config rconfig;
        inherit (
          linkagePass rdeps
            (lsuper // {
              inherit providedVersionMap;
              resolvedVersionMap = self.pinL.set lsuper.resolvedVersionMap config rconfig;
              fixedVersionMap = self.mvn.mergeFixedVersions
                lsuper.fixedVersionMap (self.mvn.pinMap rconfig.fixedVersions);

            })
        ) resolvedVersionMap fixedVersionMap;
      in
        if
          self.mvn.excluded lsuper config
          || (hasProvided && ! wouldProvide)
        then lsuper
        else if hasProvided
        then lsuper // { inherit resolvedVersionMap; }
        else
          linkagePass rdeps
            (lsuper // {
              inherit providedVersionMap resolvedVersionMap fixedVersionMap;
            });


    linkage = cfg:
      self.mvn.linkageFor cfg {
        path = [];
        exclusions = [];
        fixedVersionMap = {};
        providedVersionMap = {};
        resolvedVersionMap = {};
      };

    dependencyPath = cfg:
      (self.mvn.linkage cfg).path;

    # compilePath = cfg:
    #   let lr = linkage cfg; in
    #   (linkageFor cfg lr // {
    #     fixedVersionMap = mergePins lr.fixedVersionMap lr.providedVersionMap;
    #   }).path;

    excluded = { exclusions, ... }: { group, artifact, ... }:
      ! isNull
        (findFirst (e: dep.group == e.group && dep.artifact == e.artifact)
          null exclusions);

    versionOlder = cfg1: cfg2:
      self.lib.versionOlder
        cfg1.version
        cfg2.version;
        # (tryOr cfg1.version "" "Current resolved didn't evalue, replace")
        # (tryOr cfg2.version "" "Replacement didn't evalue, ignore");

    hydrateDependency = dep: mvn:
      if dep ? override #extension && dep ? ${dep.extension}
      then dep.override mvn
      else let
        result = self.mergeByType
          (submodule {
            options = self.mvn.optionsFor result;
          })
          (if dep.overlay or false
           then [ mvn dep ]
           else [ mvn (mkDefault dep)
                  (self.repoL.getDefault
                    mvn.repository dep (warn "Not found in repo ${toJSON dep}" {})) ]);
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
        (extension: clss:
          mapAttrs
            (classifier: grps:
              mapAttrs
                (group: arts:
                  mapAttrs
                    (artifact: vrss:
                      mapAttrs
                        (version: desc:
                          f group artifact extension classifier version desc)
                        vrss)
                    arts)
                grps)
            clss)
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

    # repos group artifact extension classifier baseVersion version
    # mirrorsFor = mavenRepos: group: name: extension: classifier: version: resolvedVersion: let
    mirrorsFor = { repos, group, artifact, extension, classifier, baseVersion ? version, version, ... }: let
      dotToSlash = replaceStrings [ "." ] [ "/" ];
      tag = if classifier == "" then "" else "-" + classifier;
      mvnPath = baseUri:
        "${baseUri}/${dotToSlash group}/${artifact}/${baseVersion}/${artifact}-${version}${tag}.${extension}";
    in map mvnPath repos;

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
