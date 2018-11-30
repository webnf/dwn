{ lib, runCommand, nix, }:

runCommand "dwn" {
  scriptFolder = ./scripts;
  nixBuild = "${nix}/bin/nix-build";
  callPackage = "${./.}/call-package.nix";
} ''
  scriptBase=$out/bin
  mkdir -p $scriptBase
  export scriptBase callPackage nixBuild
  for s in "$scriptFolder"/*; do # */ hello emacs
    target="$scriptBase/$(basename $s)"
    substituteAll "$s" "$target"
    chmod +x "$target"
  done
''
