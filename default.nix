{ callPackage
, devMode ? false
, varDirectory ? "/tmp/dwn.var"
, clojureLib ? callPackage ./src/nix/lib {}
}:
callPackage ./packages.nix {
  inherit clojureLib;
  dwnConfig = {
    inherit devMode varDirectory;
  };
}
