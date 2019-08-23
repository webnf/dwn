{ pkgs, newScope, buildWith }:

let
  build = buildWith [ ./nrepl/module.nix ];
  callPackage = newScope thisns;
  thisns = {
    inherit build;
    overlay = ./packages.nix;
    dwn = build ./dwn.nix;
    nrepl = buildWith [ ./clojure/module.nix ] ./nrepl/dwn.nix;
    lein.reader = build ./lein.reader/dwn.nix;
    mvn.reader = build ./mvn.reader/dwn.nix;
    juds = callPackage ./juds.nix {};
    dwnTool = callPackage ./dwn-tool.nix {};
  };
in thisns
