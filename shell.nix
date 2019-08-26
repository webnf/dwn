(import <nixpkgs> {
  overlays = [
    (import ./src/packages.nix)
    (import ./src/mvn/lib.nix)
    (import ./src/lib/lib-project.nix)
  ];
})
