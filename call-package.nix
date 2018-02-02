{ package
, devMode
, pkgs ? import <nixpkgs> {}}:

(pkgs.callPackage ./default.nix { inherit devMode; })
.callPackage package {}
