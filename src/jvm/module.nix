{ config, lib, pkgs, ... }:

with lib;
let
  inherit (pkgs) pathsT uniqifyingSymlinkJoin;
in

{
  imports = [
    ../mvn/module.nix
  ];
  options.dwn.jvm = {
    sourceDirectories = mkOption {
      default = [];
      type = types.listOf types.path;
      description = ''
          Source roots for jvm compilation
        '';
    };
    resourceDirectories = mkOption {
      default = [];
      type = types.listOf types.path;
      description = ''
          Resource roots for jvm compilation
        '';
    };
    runtimeClasspath = mkOption {
      default = [];
      type = pathsT;
      description = ''
          Jvm runtime classpath
        '';
    };
    runtimeArgs = mkOption {
      default = [];
      type = types.listOf types.str;
      description = "Extra JVM args";
    };
    compileClasspath = mkOption {
      default = [];
      type = pathsT;
      description = ''
          Jvm compile classpath
        '';
    };
    resultClasspath = mkOption {
      internal = true;
      type = pathsT;
    };
    dependencyClasspath = mkOption {
      default = [];
      internal = true;
      type = pathsT;
    };
    compileDependencyClasspath = mkOption {
      default = [];
      internal = true;
      type = pathsT;
    };
    javaClasses = mkOption {
      internal = true;
      type = pathsT;
    };
  };

  config.dwn.mvn.extension = "dirs";
  config.dwn.mvn.dirs =
    config.dwn.jvm.runtimeClasspath
    ++ config.dwn.jvm.javaClasses
    ++ config.dwn.jvm.resourceDirectories;

  config.dwn.jvm = {
    compileClasspath =
      config.dwn.jvm.resourceDirectories
      ++ config.dwn.jvm.compileDependencyClasspath;
    javaClasses = lib.optional
      (0 != lib.length config.dwn.jvm.sourceDirectories) (
        pkgs.jvmCompile {
          name = config.dwn.name + "-jvm-classes";
          classpath = config.dwn.jvm.compileClasspath;
          sources = config.dwn.jvm.sourceDirectories;
        });
    resultClasspath = config.dwn.jvm.runtimeClasspath
                      ++ config.dwn.jvm.javaClasses
                      ++ config.dwn.jvm.resourceDirectories
                      ++ config.dwn.jvm.dependencyClasspath;
  };
  config.dwn.paths = [
    (uniqifyingSymlinkJoin
      (config.dwn.name + "-jvm-classpath")
      config.dwn.jvm.resultClasspath)
  ];

}
