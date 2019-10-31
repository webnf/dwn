{ config, lib, pkgs, ... }:

with lib;
with types;

{
  imports = [
    ../clojure/module.nix
  ];
  options.dwn.nrepl = {
    host = mkOption {
      default = "127.0.0.1";
      type = str;
      description = ''
        Nrepl host name
      '';
    };
    port = mkOption {
      default = null;
      type = nullOr int;
      description = ''
        Nrepl port
      '';
    };
    middleware = mkOption {
      default = [];
      type = listOf str;
      description = ''
        Nrepl middleware
      '';
    };
    enable-cider = mkOption {
      default = true;
      type = bool;
      description = ''
        Enable cider on nrepl
      '';
    };
  };

  config = mkIf (! isNull config.dwn.nrepl.port) {
    dwn.mvn.dependencies = [ pkgs.nrepl ];

    dwn.clj.main = {
      dwn-nrepl = {
        namespace = "webnf.dwn.nrepl";
        prefixArgs = [ ( pkgs.toEdnPP ( pkgs.keyword-map config.dwn.nrepl)) ];
      };
    };
  };
}
