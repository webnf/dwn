{ lib, runCommand, nix, nix-repl, zsh }:

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
  ln -s ${zsh}/bin/zsh $scriptBase/dwn-zsh
  ln -s ${nix-repl}/bin/nix-repl $scriptBase/dwn-nix-repl
''
