(import <nixpkgs> {
  overlays = [ (import ./src/packages.nix) ];
})
