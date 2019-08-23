(import <nixpkgs> {
  overlays = [ (import ./src/packages.nix) ];
}) # .callPackage ./src/default.nix { }
