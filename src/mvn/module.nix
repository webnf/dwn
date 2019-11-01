{ config, lib, pkgs, overrideConfig, ... }:

with lib;
with types;

let
  inherit (pkgs) pathT pathsT urlT coordinateListT
    subPath closureRepoGenerator;
  haveSha1 = ! isNull config.dwn.mvn.sha1;
in

{
  imports = [
    ../base-module.nix
  ];

  options.dwn.mvn = (pkgs.mvn.optionsFor config.dwn.mvn) // {
    fixedDependencies = mkOption {
      default = [];
      type = listOf pkgs.mvn.dependencyT;
      description = ''
        Combination of dependencies and fixedVersions.
      '';
    };
    overlayRepository = mkOption {
      internal = true;
      type = unspecified; #pkgs.mvn.repoT;
    };
    repositoryFile = mkOption {
      default = warn "Please set and generate repository file ${config.dwn.name}" null;
      type = nullOr path;
      description = ''
        Path of closure file, generated with SHAs of dependency tree.
      '';
    };
    repositoryUpdater = mkOption {
      default = closureRepoGenerator {
        inherit (config.dwn.mvn) repositoryFile repos dependencies fixedVersions overlayRepository providedVersions;
      };
      type = either package path;
    };
    repositoryFormat = mkOption {
      internal = true;
      default = "repo-edn";
      type = str;
    };
  };

  config = {
    dwn = {
      name = mkDefault (config.dwn.mvn.group + "__" + config.dwn.mvn.artifact + "__" + config.dwn.mvn.version);
      mvn = {
        override = mvn:
          (overrideConfig (cfg:
            cfg // {
              dwn = cfg.dwn // {
                mvn = cfg.dwn.mvn // mvn;
              };
            })).dwn.mvn;
        overlay = true;
        overlayRepository = pkgs.mvn.overlayFor config.dwn.mvn {};
        dependencies = config.dwn.mvn.fixedDependencies;
        fixedVersions = config.dwn.mvn.fixedDependencies;
        repository = lib.mkIf (! isNull config.dwn.mvn.repositoryFile
                               && pathExists config.dwn.mvn.repositoryFile)
          (lib.importJSON config.dwn.mvn.repositoryFile);
      };
      jvm.dependencyClasspath = pkgs.mvn.dependencyClasspath (pkgs.mvn.dependencyPath config.dwn.mvn);
      jvm.compileClasspath = pkgs.mvn.dependencyClasspath (pkgs.mvn.compilePath config.dwn.mvn);
      paths = [] ++ lib.optional
        config.dwn.dev
        (subPath "bin/regenerate-repo" config.dwn.mvn.repositoryUpdater);
    };
  };
}
