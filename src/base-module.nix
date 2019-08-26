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
in
{
  options.dwn = {
    dev = mkOption {
      default = false;
      type = types.bool;
      description = ''
        Development mode
      '';
    };
    optimize = mkOption {
      default = false;
      type = types.bool;
      description = ''
        Optimized compilation
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
    binaries = mkOption {
      default = {};
      type = types.attrsOf types.package;
    };
    plugins = mkOption {
      default = [];
      type = types.listOf types.unspecified;
      description = "plugin modules";
    };
  };

  options.result = mkOption {
    type = types.package;
    description = ''
      The final result package
    '';
  };

  options.passthru = mkOption {
    default = {};
    type = mkOptionType rec {
      name = "recursive-merged-attrs";
      description = "Maven dependency coordinate";
      check = lib.isAttrs;
      merge = loc: defs:
        lib.foldl lib.recursiveUpdate
          {} (getValues defs);
    };
  };

  config.dwn.paths = lib.mapAttrsToList
    (name: path:
      subPath "bin/${name}" path)
    config.dwn.binaries;

  config.result = (pkgs.buildEnv {
    inherit (config.dwn) name paths;
  }) // (
    lib.recursiveUpdate
      {
        inherit (config) dwn;
      }
      config.passthru
  );
}
