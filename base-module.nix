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
  };

  options.result = mkOption {
    type = types.package;
    description = ''
      The final result package
    '';
  };

  config.dwn.paths = [ pkgs.dwnTool ];

  config.result = (pkgs.buildEnv {
    inherit (config.dwn) name paths;
  }) // {
    inherit (config) dwn;
  };
}
