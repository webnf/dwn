{ config, lib, pkgs, ... }:

with lib;
let paths = types.listOf (types.either types.path types.package); in

{
  options.dwn = {
    dev = mkOption {
      default = false;
      type = types.bool;
      description = ''
        Development mode
      '';
    };
    name = mkOption {
      default = "dwn-result";
      type = types.string;
      description = ''
        Package result name
      '';
    };
    paths = mkOption {
      default = [];
      type = paths;
      description = ''
        Derivations / paths of which to compose outputs
      '';
    };
    # jvm = {
    #   sourceDirectories = mkOption {
    #     default = [];
    #     type = types.listOf types.path;
    #     description = ''
    #       Source roots for jvm compilation
    #     '';
    #   };
    #   runtimeClasspath = mkOption {
    #     type = paths;
    #     description = ''
    #       Jvm compile classpaths
    #     '';
    #   };
    #   compileClasspath = mkOption {
    #     default = [];
    #     type = paths;
    #     description = ''
    #       Jvm runtime classpaths
    #     '';
    #   };
    # };
  };
  
  options.result = mkOption {
    type = types.package;
    description = ''
      The final result package
    '';
  };

  config.result = (pkgs.buildEnv {
    inherit (config.dwn) name paths;
  }) // {
    config = config.dwn;
  };

  # config.dwn.jvm.runtimeClasspath = (lib.optional (0 != lib.length config.dwn.jvm.sourceDirectories) (
  #   pkgs.jvmCompile {
  #     name = config.dwn.name + "-jvm-classes";
  #     classpath = config.dwn.jvm.compileClasspath;
  #     sources = config.dwn.jvm.sourceDirectories;
  #   }
  # ));
  
  # config.dwn.paths = [(pkgs.runCommand "jvm-classpath" {
  #   inherit (config.dwn.jvm) runtimeClasspath;
  # } ''
  #   mkdir -p $out/share/java
  #   cd $out/share/java
  #   for c in $runtimeClasspath; do
  #     local targetOrig=$out/share/java/$(stripHash $c)
  #     local target=$targetOrig
  #     local cnt=0
  #     while [ -L $target ]; do
  #       target=$targetOrig-$cnt
  #       cnt=$(( cnt + 1 ))
  #     done
  #     ln -s $c $target
  #   done
  # '')];
}
