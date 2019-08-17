{ project, symbol, lib, devMode
, providedVersions ? []}:

project {
  group = "webnf.dwn";
  name = "nrepl";
  version = "0.0.1";

  inherit devMode providedVersions;

  cljSourceDirs = [ ./nrepl-cmp ];
  dependencies = [
    ["org.clojure" "clojure" "1.10.1"]
    ["com.stuartsierra" "component" "0.4.0"]
    ["cider" "cider-nrepl" "0.21.1"]
    ["refactor-nrepl" "2.4.0"]
    ["org.clojure" "tools.logging" "0.4.1"]
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

# ; in prj // {
#   pluginInit = attrs: attrs // {
#     dependencies = attrs.dependencies or [] ++ [ prj ];
#     initForms = (attrs.initForms or [])
#       ++ lib.optional (attrs.startNrepl or attrs.devMode or devMode) ''
#         (do
#         (ns webnf.dwn.nrepl.entry
#           :require [webnf.dwn.nrepl])
#         (def server
#          (webnf.dwn.nrepl/nrepl
#           {:host "localhost"
#            :port 1337
#            :middleware []
#            :enable-cider true}))
#         (future (com.stuartsierra.component/start server))
#         (in-ns 'user)
#         )
#       '';
#   };
# }
