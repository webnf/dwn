{ dwn
, meta ? { dwn = { group = "webnf.dwn"; name = "nrepl"; version = "DEVEL"; }; }
}:

dwn.build {
  inherit (meta.dwn) group name version;
  dependencies = [
    ["org.clojure" "tools.nrepl"]
    ["refactor-nrepl" "refactor-nrepl"]
    ["cider" "cider-nrepl"]
    ["org.tcrawley" "dynapath"]
  ];
  source-paths = [ ./nrepl-cmp ];
}
