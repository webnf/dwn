{ config, lib, pkgs, ... }:

with lib;
let paths = types.listOf (types.either types.path types.package); in

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
          Jvm compile classpaths
        '';
    };
    compileClasspath = mkOption {
      default = [];
      type = paths;
      description = ''
          Jvm runtime classpaths
        '';
    };
  };

  config.dwn.paths = [
    (pkgs.runCommand "jvm-classpath" {
      classpath =
        config.dwn.jvm.runtimeClasspath
        ++ (
          lib.optional
            (0 != lib.length config.dwn.jvm.sourceDirectories) (
              pkgs.jvmCompile {
                name = config.dwn.name + "-jvm-classes";
                classpath = config.dwn.jvm.compileClasspath;
                sources = config.dwn.jvm.sourceDirectories;
              }));
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
  '')];
  
}
