rec {
  pkgs = import <nixpkgs> {};
  clojure = pkgs.callPackage ./src/nix/lib/clojure.nix {};
  config = clojure.callPackage ./config.nix { };
  edn = clojure.callPackage ./config.edn.nix { };
}
