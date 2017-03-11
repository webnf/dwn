{ callPackage }:
callPackage ./packages.nix {
  clojureLib = callPackage ./src/nix/lib {};
  dwnConfig = {
    devMode = true;
    varDirectory = "/tmp/dwn.var";
  };
}
