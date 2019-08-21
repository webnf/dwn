{ config, lib, pkgs, ... }:

with lib;
let
  paths = types.listOf (types.either types.path types.package);
  dependencyT = mkOptionType rec {
    name = "maven-dependency";
    description = "Maven dependency coordinate";
    ## TODO syntax check
    check = v: builtins.isList v || builtins.isAttrs v;
    merge = mergeEqualOption;
  };
  subPath = path: drv: pkgs.runCommand (drv.name + "-" + lib.replaceStrings ["/"] ["_"] path) {
    inherit path;
  } ''
    mkdir -p $out/$(dirname $path)
    ln -s ${drv} $out/$path
  '';
  uniqifyingSymlinkJoin = name: classpath: pkgs.runCommand name {
    inherit classpath;
  } ''
    mkdir -p $out/share/java
    cd $out/share/java
    for c in $classpath; do
      local targetOrig=$out/share/java/$(stripHash $c)
      local target=$targetOrig
      local cnt=0
      while [ -L $target ]; do
        target=$targetOrig-$cnt
        cnt=$(( cnt + 1 ))
      done
      ln -s $c $target
    done
  '';
in

{
  options.dwn.jvm = {
    sourceDirectories = mkOption {
      default = [];
      type = types.listOf types.path;
      description = ''
          Source roots for jvm compilation
        '';
    };
    runtimeClasspath = mkOption {
      default = [];
      type = paths;
      description = ''
          Jvm runtime classpath
        '';
    };
    compileClasspath = mkOption {
      default = [];
      type = paths;
      description = ''
          Jvm compile classpath
        '';
    };
    resultClasspath = mkOption {
      internal = true;
      type = paths;
    };
    dependencyClasspath = mkOption {
      internal = true;
      type = paths;
    };
    javaClasses = mkOption {
      internal = true;
      type = paths;
    };
  };

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
  };

  config.dwn.jvm = {
    dependencyClasspath = lib.optionals
      (0 != lib.length config.dwn.mvn.dependencies) (
        pkgs.dependencyClasspath {
          name = config.dwn.name + "-mvn-classpath";
          mavenRepos = config.dwn.mvn.repos;
          closureRepo = config.dwn.mvn.repositoryFile;
          inherit (config.dwn.mvn) dependencies;
        });
    compileClasspath = config.dwn.jvm.dependencyClasspath;
    javaClasses = lib.optional
      (0 != lib.length config.dwn.jvm.sourceDirectories) (
        pkgs.jvmCompile {
          name = config.dwn.name + "-jvm-classes";
          classpath = config.dwn.jvm.compileClasspath;
          sources = config.dwn.jvm.sourceDirectories;
        });
    resultClasspath = config.dwn.jvm.runtimeClasspath
                      ++ config.dwn.jvm.javaClasses
                      ++ config.dwn.jvm.dependencyClasspath;
  };
  config.dwn.paths = [
    (subPath "share/java"
      (uniqifyingSymlinkJoin
        (config.dwn.name + "-jvm-classpath")
        config.dwn.jvm.resultClasspath))];
  
}
