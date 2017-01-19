((import <nixpkgs> {})
 .callPackage ./src/nix/lib/clojure.nix {})
.callPackage ./deps.aether { }
