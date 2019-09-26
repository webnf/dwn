{ config, lib, pkgs, overrideConfig, ... }:

with lib;
let
  inherit (pkgs) dependencyT plainDependencyT repoT pathT pathsT urlT coordinateListT
    subPath closureRepoGenerator mvnResult dependencyClasspath;
in

{
  imports = [
    ../base-module.nix
  ];

  options.dwn.mvn = {
    group = mkOption {
      type = types.str;
      default = config.dwn.mvn.artifact;
      description = "Maven group";
    };
    artifact = mkOption {
      type = types.str;
      description = "Maven artifact";
    };
    version = mkOption {
      type = types.str;
      description = "Maven version";
    };
    extension = mkOption {
      type = types.str;
      default = "dirs";
      description = "Maven packaging extension";
    };
    classifier = mkOption {
      type = types.str;
      default = "";
      description = "Maven classifier";
    };
    repos = mkOption {
      default = [ http://repo1.maven.org/maven2
                  https://clojars.org/repo ];
      type = types.listOf urlT;
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
    fixedVersions = mkOption {
      default = [];
      type = types.listOf dependencyT;
      description = ''
        Override versions from dependencies (transitive).
      '';
    };
    fixedDependencies = mkOption {
      default = [];
      type = types.listOf dependencyT;
      description = ''
        Dependencies with fixed versions.
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
      default = closureRepoGenerator {
        inherit (config.passthru.dwn.mvn) dependencies fixedVersions overlayRepository;
        inherit (config.dwn.mvn) repositoryFile repos;
      };
      type = types.either types.package types.path;
    };
    dirs = mkOption {
      default = null;
      type = types.nullOr pathsT;
    };
    jar = mkOption {
      default = null;
      type = types.nullOr pathT;
    };
    repositoryFormat = mkOption {
      internal = true;
      default = "repo-edn";
      type = types.str;
    };
  };

  config.dwn.name = mkDefault (config.dwn.mvn.group + "_" + config.dwn.mvn.artifact);
  config.dwn.mvn.dependencies = config.dwn.mvn.fixedDependencies;
  config.dwn.mvn.fixedVersions = config.dwn.mvn.fixedDependencies;

  config.passthru.dwn.mvn = mvnResult overrideConfig config.dwn.mvn;
  config.passthru.mvnResult2 = pkgs.mvnResult2 overrideConfig config.dwn.mvn;

  config.dwn.jvm.dependencyClasspath =
    lib.optionals
      (0 != lib.length config.dwn.mvn.dependencies
       && (
         if isNull config.dwn.mvn.repositoryFile then
           warn "Please set and generate repository file ${config.dwn.name}" false
         else
           true))
      (if "repo-edn" == config.dwn.mvn.repositoryFormat
       then pkgs.dependencyClasspath2 config
       else if "repo-json" == config.dwn.mvn.repositoryFormat
       then config.passthru.mvnResult.dependencyClasspath
       else throw "Unknown repository format ${config.dwn.mvn.repositoryFormat}");
  config.dwn.paths = [] ++ lib.optional
    config.dwn.dev
    (subPath "bin/regenerate-repo" config.dwn.mvn.repositoryUpdater);

}
