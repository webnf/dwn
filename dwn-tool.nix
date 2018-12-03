{ lib, runCommand, nix, zsh }:

runCommand "dwn" {
  scriptFolder = ./scripts;
  inherit nix;
  callPackage = "${./.}/call-package.nix";
  shell = "${zsh}/bin/zsh";
} ''
  scriptBase=$out/bin
  mkdir -p $scriptBase
  export scriptBase callPackage nixBuild
  for s in "$scriptFolder"/*; do # */ hello emacs
    target="$scriptBase/$(basename $s)"
    substituteAll "$s" "$target"
    chmod +x "$target"
  done
  ln -s ${zsh}/bin/zsh $scriptBase/dwn-zsh
  ln -s ${nix}/bin/nix $scriptBase/dwn-nix
''
