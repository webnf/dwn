{ config, lib, pkgs, ... }:

with lib;
let
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
in

{

  options.dwn.mvn = {
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
    repositoryFile = mkOption {
      type = types.path;
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
  };

  config.dwn.jvm.dependencyClasspath =
    lib.optionals
    (0 != lib.length config.dwn.mvn.dependencies)
    (pkgs.dependencyClasspath {
      name = config.dwn.name + "-mvn-classpath";
      mavenRepos = config.dwn.mvn.repos;
      closureRepo = config.dwn.mvn.repositoryFile;
      inherit (config.dwn.mvn) dependencies;
    });
  config.dwn.paths = [
    (subPath "bin/regenerate-repo" config.dwn.mvn.repositoryUpdater)
  ];
  
}
