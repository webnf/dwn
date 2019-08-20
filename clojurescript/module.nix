{ config, lib, pkgs, ... }:

with lib;

{
  options.dwn.cljs = {
    sourceDirectories = mkOption {
      default = [];
      type = types.listOf types.path;
      description = ''
        Source roots for clojurescript compilation
      '';
    };
  };

  config = mkIf (0 != lib.length config.dwn.cljs.sourceDirectories) {
    dwn.paths =
      if config.dwn.dev then
        (map toString config.dwn.cljs.sourceDirectories)
        ++ [(pkgs.writeScriptBin "start-figwheel" ''
           echo Start figwheel ${toString config.dwn.cljs.sourceDirectories}
        '')]
      else
        [];
  };
}
