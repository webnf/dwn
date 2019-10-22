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
      default = null;
      type = types.nullOr types.path;
      description = ''
        Path of closure file, generated with SHAs of dependency tree.
      '';
    };
    repositoryUpdater = mkOption {
      default = closureRepoGenerator {
        inherit (config.passthru.dwn.mvn) dependencies fixedVersions overlayRepository;
        inherit (config.dwn.mvn) repositoryFile repos;
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
    # passthru.dwn.mvn = mvnResult overrideConfig config.dwn.mvn;
    # passthru.mvnResult3 = pkgs.mvnResult3 (pkgs.mvn.pimpConfig config);
    # passthru.dwn.mvn.linkAsDependency = pkgs.mvn.linkAsDependency config.dwn.mvn;

    dwn = {
      name = mkDefault (config.dwn.mvn.group + "__" + config.dwn.mvn.artifact + "__" + config.dwn.mvn.version);
      mvn = {
        dependencies = config.dwn.mvn.fixedDependencies;
        fixedVersions = config.dwn.mvn.fixedDependencies;
        repository = lib.mkIf (! isNull config.dwn.mvn.repositoryFile)
          (lib.importJSON config.dwn.mvn.repositoryFile);
      };
      jvm.dependencyClasspath =
        lib.optionals
          (0 != lib.length config.dwn.mvn.dependencies
           && (
             if isNull config.dwn.mvn.repositoryFile then
               warn "Please set and generate repository file ${config.dwn.name}" false
             else
               true))
          (pkgs.mvn.dependencyClasspath (pkgs.mvn.resolve config.dwn.mvn).dependencies);
      paths = [] ++ lib.optional
        config.dwn.dev
        (subPath "bin/regenerate-repo" config.dwn.mvn.repositoryUpdater);
    };    
  };
}
