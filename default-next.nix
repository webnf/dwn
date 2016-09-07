((import <nixpkgs> {})
 .callPackage ./src/nix/lib/clojure.nix {})
.callPackage ./dwn-next.nix {}
