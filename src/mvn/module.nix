{ config, lib, pkgs, overrideConfig, ... }:

with lib;
let
  inherit (pkgs) dependencyT plainDependencyT repoT pathT pathsT urlT coordinateListT
    subPath closureRepoGenerator mvnResult dependencyClasspath;
  haveSha1 = ! isNull config.dwn.mvn.sha1;
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
    baseVersion = mkOption {
      default = config.dwn.mvn.version;
      type = types.str;
      description = "Base (path) maven version";
    };
    extension = mkOption {
      type = types.str;
      default = if haveSha1 then "jar" else "dirs";
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
      type = types.listOf dependencyT; # pkgs.mvn.dependencyT;
      description = ''
        Maven dependencies.
      '';
    };
    exclusions = mkOption {
      default = [];
      ## FIXME coordinate w/o version
      type = types.listOf dependencyT;
      description = ''
        Maven exclusions
      '';
    };
    providedVersions = mkOption {
      default = [];
      type = types.listOf dependencyT;
      description = ''
        Dependencies, that are already on the classpath. Either from a container, or previous dependencies.
      '';
    };
    fixedVersions = mkOption {
      default = [];
      type = types.listOf dependencyT;
      description = ''
        Override versions from dependencies (transitive).
        As opposed to `providedVersions`, this will include a dependency, but at the pinned version.
      '';
    };
    fixedDependencies = mkOption {
      default = [];
      type = types.listOf dependencyT;
      description = ''
        Combination of dependencies and fixedVersions.
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
      default = throw "No dirs for ${config.dwn.name}";
      type = pathsT;
    };
    jar = mkOption {
      default = throw "No jar file for ${config.dwn.name}";
      type = pathT;
    };
    sha1 = mkOption {
      default = null;
      type = types.nullOr types.str;
    };
    repositoryFormat = mkOption {
      internal = true;
      default = "repo-edn";
      type = types.str;
    };
  };

  config = {
    # passthru.dwn.mvn = mvnResult overrideConfig config.dwn.mvn;
    passthru.mvnResult3 = pkgs.mvnResult3 (pkgs.mvn.pimpConfig config);

    dwn = {
      name = mkDefault (config.dwn.mvn.group + "_" + config.dwn.mvn.artifact + "_" + config.dwn.mvn.version);
      mvn = {
        dependencies = config.dwn.mvn.fixedDependencies;
        fixedVersions = config.dwn.mvn.fixedDependencies;
        jar = lib.mkIf haveSha1
          ((pkgs.fetchurl (with config.dwn.mvn; {
            name = "${config.dwn.name}.${config.dwn.mvn.extension}";
            urls = pkgs.mavenMirrors
              config.dwn.mvn.repos
              config.dwn.mvn.group
              config.dwn.mvn.artifact
              config.dwn.mvn.extension
              config.dwn.mvn.classifier
              config.dwn.mvn.baseVersion
              config.dwn.mvn.version;
            inherit (config.dwn.mvn) sha1;
            # prevent nix-daemon from downloading maven artifacts from the nix cache
          })) // { preferLocalBuild = true; });
        overlayRepository = lib.mkIf (! isNull config.dwn.mvn.repositoryFile
                                      && "repo-json" == config.dwn.mvn.repositoryFormat)
          pkgs.mvn.hydrateJsonRepository config.dwn.mvn.repositoryFile;
      };
      jvm.dependencyClasspath =
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
           then pkgs.mvn.dependencyClasspath (pkgs.mvn.resolve { inherit (config.passthru) mvnResult3; }).dependencies
           else throw "Unknown repository format ${config.dwn.mvn.repositoryFormat}");
      paths = [] ++ lib.optional
        config.dwn.dev
        (subPath "bin/regenerate-repo" config.dwn.mvn.repositoryUpdater);
    };    
  };
}
