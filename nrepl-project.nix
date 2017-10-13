{ project, symbol, lib, devMode, providedVersions }:

project {

  name = "webnf.dwn.nrepl";

  inherit devMode providedVersions;

  cljSourceDirs = [ ./nrepl-cmp ];
  dependencies = [
    ["org.clojure" "clojure" "1.9.0-alpha16"]
    ["org.clojure" "tools.logging" "0.3.1"]
    ["com.stuartsierra" "component" "0.3.2"]
    ["org.clojure" "tools.nrepl" "0.2.13"]
    ["cider" "cider-nrepl" "0.14.0"]
    ["refactor-nrepl" "2.3.0"]
  ];

  aot = lib.optionals (! devMode) [ "webnf.dwn.nrepl" ];

  components = {
    server = {
      factory = symbol "webnf.dwn.nrepl" "nrepl";
      options = with lib; {
        host = mkOption {
          type = types.string;
          doc = "host name / ip address to bind to";
          default = "0.0.0.0";
        };
        port = mkOption {
          type = types.nullOr types.int;
          doc = "port to bind to";
          default = null;
        };
        middleware = mkOption {
          type = types.listOf types.symbol;
          doc = "Nrepl middlewares";
          default = [ ];
        };
        enable-cider = mkOption {
          type = types.boolean;
          doc = "Whether to add cider middleware";
          default = true;
        };
      };
    };
  };
  closureRepo = ./nrepl.repo.edn;
}
