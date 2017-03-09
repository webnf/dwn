{ dwn, keyword, symbol, keyword-map }:

keyword-map {
  # defined implicitly from project classpath
  # "webnf.dwn/app-loader" = dwn.container { };

  "webnf.dwn.nrepl/cider-mixin-container" = dwn.container {
    parent = keyword "webnf.dwn" "app-loader";
    classpath = dwn.artefactClasspath repository ["webnf.dwn" "nrepl"];
  };

  "webnf.dwn/main" = dwn.ns-launcher {
    container = keyword "webnf.dwn" "app-loader";
    main = (symbol null "webnf.dwn.boot");
    args = [ configLocation ];
  };

  "webnf.dwn.nrepl/server" = dwn.component {
    factory = symbol "webnf.dwn.nrepl" "nrepl";
    config = {
      host = "0.0.0.0";
      port = 1271;
      middleware = [];
      enable-cider = true;
    };
    container = keyword "webnf.dwn.nrepl" "cider-mixin-container";
  };

}
