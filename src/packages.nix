self: super:

with self;
with lib;
{

  inherit (edn) asEdn toEdn toEdnPP;
  inherit (edn.syntax) tagged hash-map keyword-map list vector set symbol keyword string int bool nil;
  inherit (edn.data) get get-in eq nth nix-str nix-list extract;

  dwn = build ./dwn.nix;
  nrepl = build ./nrepl/dwn.nix;
  lein.reader = build ./lein.reader/dwn.nix;
  mvn = (super.mvn or {}) // {
    reader = build ./mvn.reader/dwn.nix;
  };

  juds = build ./juds/dwn.nix;
  dwnTool = callPackage ./dwn-tool.nix { };

  clojure = build ./clojure/dwn.nix;
  clojurescript = build ./clojurescript/dwn.nix;
  deps = {
    # expander = build ./deps.expander/dwn.nix;
    aether = build ./deps.aether/dwn-bootstrap.nix;
  };

  aether = build ./deps.aether/dwn.nix;

  updaterFor = { pkg }:
    if pkg ? dwn.mvn.repositoryUpdater
    then pkg.dwn.mvn.repositoryUpdater
    else (self.buildWith [ ./clojure/module.nix { _module.check = false; } ] lib.id pkg).dwn.mvn.repositoryUpdater;

  builderFor = { pkg }:
    if pkg ? dwn.mvn.repositoryUpdater
    then pkg.dwn.mvn.repositoryUpdater
    else (self.buildWith [ ./clojure/module.nix { _module.check = false; } ] lib.id pkg).result;

}
