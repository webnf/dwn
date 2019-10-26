{ config, lib, pkgs, overrideConfig, ... }:

with lib;
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
      type = types.listOf pkgs.mvn.dependencyT;
      description = ''
        Combination of dependencies and fixedVersions.
      '';
    };
    overlayRepository = mkOption {
      default = {};
      type = pkgs.mvn.repoT;
      description = "Repository of non-maven artifacts";
    };
    repositoryFile = mkOption {
      default = warn "Please set and generate repository file ${config.dwn.name}" null;
      type = types.nullOr types.path;
      description = ''
        Path of closure file, generated with SHAs of dependency tree.
      '';
    };
    repositoryUpdater = mkOption {
      default = closureRepoGenerator {
        inherit (config.dwn.mvn) repositoryFile repos dependencies fixedVersions overlayRepository providedVersions;
      };
      type = types.either types.package types.path;
    };
    repositoryFormat = mkOption {
      internal = true;
      default = "repo-edn";
      type = types.str;
    };
  };

  config = {
    dwn = {
      name = mkDefault (config.dwn.mvn.group + "__" + config.dwn.mvn.artifact + "__" + config.dwn.mvn.version);
      mvn = {
        dependencies = config.dwn.mvn.fixedDependencies;
        fixedVersions = config.dwn.mvn.fixedDependencies;
        repository = lib.mkIf (! isNull config.dwn.mvn.repositoryFile)
          (lib.importJSON config.dwn.mvn.repositoryFile);
        overrideLinkage = linkage:
          if linkage == config.dwn.mvn.linkage
          then config.dwn.mvn
          else (overrideConfig
            (cfg: cfg // { dwn = cfg.dwn // { mvn = cfg.dwn.mvn // { inherit linkage; }; }; })
          ).dwn.mvn;
      };
      jvm.dependencyClasspath = pkgs.mvn.dependencyClasspath config.dwn.mvn.resultLinkage.path;
      jvm.compileClasspath = pkgs.mvn.dependencyClasspath
        (config.dwn.mvn.overrideLinkage config.dwn.mvn.linkage // {
          fixedVersionMap = config.dwn.mvn.linkage.fixedVersionMap // config.dwn.mvn.linkage.providedVersionMap;
          providedVersionMap = {};
        }).resultLinkage.path;
      paths = [] ++ lib.optional
        config.dwn.dev
        (subPath "bin/regenerate-repo" config.dwn.mvn.repositoryUpdater);
    };    
  };
}
