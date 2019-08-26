{ config, lib, pkgs, ... }:

with lib;
let
  paths = types.listOf (types.either types.path types.package);
  subPath = path: drv: pkgs.runCommand (drv.name + "-" + lib.replaceStrings ["/"] ["_"] path) {
    inherit path;
  } ''
    mkdir -p $out/$(dirname $path)
    ln -s ${drv} $out/$path
  '';
  dependencyT = mkOptionType rec {
    name = "maven-dependency";
    description = "Maven dependency coordinate";
    ## TODO syntax check
    check = v: builtins.isList v || builtins.isAttrs v;
    merge = mergeEqualOption;
  };
  plainDependencyT = mkOptionType rec {
    name = "maven-list-dependency";
    description = "Maven dependency coordinate";
    ## TODO syntax check
    check = v: builtins.isList v;
    merge = mergeEqualOption;
  };
  depType = subT:
    types.attrsOf subT;
  repoT = with types;
    depType
      (depType
        (depType
          (depType
            (depType
              (submodule {
                options = {
                  dependencies = mkOption {
                    default = [];
                    type = types.listOf plainDependencyT;
                  };
                  sha1 = mkOption {
                    default = null;
                    type = nullOr string;
                  };
                  jar = mkOption {
                    default = null;
                    type = nullOr string;
                  };
                  dirs = mkOption {
                    default = null;
                    type = nullOr string;
                  };
                };
              })))));
in

{
  imports = [
    ./base-module.nix
  ];

  options.dwn.mvn = {
    group = mkOption {
      type = types.string;
      default = config.dwn.mvn.artifact;
      description = "Maven group";
    };
    artifact = mkOption {
      type = types.string;
      description = "Maven artifact";
    };
    version = mkOption {
      type = types.string;
      description = "Maven version";
    };
    extension = mkOption {
      type = types.string;
      default = "dirs";
      description = "Maven packaging extension";
    };
    classifier = mkOption {
      type = types.string;
      default = "";
      description = "Maven classifier";
    };
    repos = mkOption {
      default = [ http://repo1.maven.org/maven2
                  https://clojars.org/repo ];
      type = types.listOf (types.either types.path types.string);
      description = ''
        Maven repositories
      '';
    };
    dependencies = mkOption {
      default = [];
      type = types.listOf dependencyT;
      description = ''
        Maven dependencies.
      '';
    };
    overlayRepository = mkOption {
      default = {};
      type = repoT;
      description = "Repository of non-maven artifacts";
    };
    repositoryFile = mkOption {
      default = null;
      type = types.nullOr types.path;
      description = ''
        Path of closure file, generated with SHAs of dependency tree.
      '';
    };
    repositoryUpdater = mkOption {
      default = pkgs.closureRepoGenerator
        (with config.dwn.mvn; {
          inherit dependencies;
          closureRepo = repositoryFile;
          mavenRepos = repos;
        });
      type = types.either types.package types.path;
    };
    dirs = mkOption {
      default = null;
      type = types.nullOr paths;
    };
  };

  config.passthru.dwn.mvn =
    pkgs.dwn.mvn.result
      config.dwn.mvn;
  config.dwn.jvm.dependencyClasspath =
    lib.optionals
    (0 != lib.length config.dwn.mvn.dependencies && ! isNull config.dwn.mvn.repositoryFile)
    (pkgs.dependencyClasspath {
      name = config.dwn.name + "-mvn-classpath";
      mavenRepos = config.dwn.mvn.repos;
      closureRepo = config.dwn.mvn.repositoryFile;
      inherit (config.dwn.mvn) dependencies;
    });
  config.dwn.paths = lib.optional
    config.dwn.dev
    (subPath "bin/regenerate-repo" config.dwn.mvn.repositoryUpdater);

}
