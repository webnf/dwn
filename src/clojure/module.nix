{ config, lib, pkgs, ... }:

with lib;
let
  sourceDir = if config.dwn.dev then toString else lib.id;
in

{
  imports = [
    ../jvm/module.nix
    ../systemd/module.nix
  ];
  options.dwn.clj = {
    main = mkOption {
      default = {};
      type = types.attrsOf (types.submodule {
        options = {
          namespace = mkOption {
            type = types.str;
            description = "Clojure namespace to launch";
          };
          prefixArgs = mkOption {
            default = [];
            type = types.listOf types.str;
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
      default = if config.dwn.optimize
                then lib.mapAttrsToList (_: { namespace, ...}: namespace) config.dwn.clj.main
                else [];
      type = types.listOf types.str;
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
      default = config.dwn.dev && ! config.dwn.optimize;
      type = types.bool;
      description = ''
        Clojure compiler option `disable-locals-clearing`
      '';
    };
    directLinking = mkOption {
      default = config.dwn.optimize;
      type = types.bool;
      description = ''
        Clojure compiler option `direct-linking`
      '';
    };
    elideMeta = mkOption {
      default = if config.dwn.optimize then [":line" ":file" ":doc" ":added"] else [];
      type = types.listOf types.str;
      description = ''
        Clojure compiler option `elide-meta`
      '';
    };
    customClojure = mkOption {
      default = true;
      type = types.bool;
      description = ''
        Use version of clojure, patched for more accurate compilation.
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
      dependencies = lib.optional config.dwn.clj.customClojure pkgs.clojure;
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
    dwn.binaries = lib.mapAttrs binderFor config.dwn.clj.main;
  };
}
