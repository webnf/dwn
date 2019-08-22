{ config, lib, pkgs, ... }:

with lib;
let
  paths = types.listOf (types.either types.path types.package);
  subPath = path: drv: pkgs.runCommand (drv.name + "-" + lib.replaceStrings ["/"] ["_"] path) {
    inherit path;
  } ''
    mkdir -p $out/$(dirname $path)
    ln -s ${drv} $out/$path
  '';
  sourceDir = if config.dwn.dev then toString else lib.id;
in

{
  imports = [
    ../jvm-module.nix
    ../systemd-module.nix
  ];
  options.dwn.clj = {
    main = mkOption {
      default = {};
      type = types.attrsOf (types.submodule {
        options = {
          namespace = mkOption {
            type = types.string;
            description = "Clojure namespace to launch";
          };
          prefixArgs = mkOption {
            default = [];
            type = types.listOf types.string;
            description = "Prefix arguments for -main function";
          };
        };
      });
    };
    sourceDirectories = mkOption {
      default = [];
      type = types.listOf types.path;
      description = ''
        Source roots for clojure compilation
      '';
    };
    aot = mkOption {
      default = [];
      type = types.listOf types.string;
      description = ''
        Clojure namespaces to AOT compile
      '';
    };
    warnOnReflection = mkOption {
      default = true;
      type = types.bool;
      description = ''
        Clojure compiler option `warn-on-reflection`
      '';
    };
    uncheckedMath = mkOption {
      default = false;
      type = types.bool;
      description = ''
        Clojure compiler option `unchecked-math`
      '';
    };
    disableLocalsClearing = mkOption {
      default = config.dwn.dev;
      type = types.bool;
      description = ''
        Clojure compiler option `disable-locals-clearing`
      '';
    };
    directLinking = mkOption {
      default = false;
      type = types.bool;
      description = ''
        Clojure compiler option `direct-linking`
      '';
    };
    elideMeta = mkOption {
      default = if config.dwn.dev then [] else [":line" ":file" ":doc" ":added"];
      type = types.listOf types.string;
      description = ''
        Clojure compiler option `elide-meta`
      '';
    };
  };

  config = let
    binderFor = name: { namespace, prefixArgs, ... }:
      pkgs.shellBinder.mainLauncher {
        classpath = config.dwn.jvm.resultClasspath;
        jvmArgs = config.dwn.jvm.runtimeArgs;
        inherit name namespace prefixArgs;
      };
  in mkIf (0 != lib.length config.dwn.clj.sourceDirectories) {
    dwn.mvn = {
      dependencies = [ pkgs.clojure ];
    };
    dwn.jvm.runtimeClasspath =
      (map sourceDir config.dwn.clj.sourceDirectories)
      ++ (lib.optional (0 != lib.length config.dwn.clj.aot) (
        pkgs.cljCompile {
          name = config.dwn.name + "-clj-classes";
          inherit (config.dwn.clj) aot;
          classpath = config.dwn.clj.sourceDirectories ++ config.dwn.jvm.javaClasses ++ config.dwn.jvm.compileClasspath;
          options = {
            inherit (config.dwn.clj) warnOnReflection uncheckedMath disableLocalsClearing elideMeta directLinking;
          };
        }
      ));
    dwn.systemd.services = lib.mapAttrs
      (name: { namespace, prefixArgs, ... }@args: {
        description = "${name}: clojure.main -m ${namespace} ${pkgs.toEdn prefixArgs} \"$@\"";
        serviceConfig = {
          Type="oneshot";
          ExecStart="${(binderFor name args)}";
        };
      })
      config.dwn.clj.main;
    dwn.paths = lib.mapAttrsToList
      (name: args:
        subPath "bin/${name}" (binderFor name args))
      config.dwn.clj.main;
      };
  }
