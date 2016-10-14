{ writeText, callPackage, runCommand, dwn, edn, mvnCatalog
, repository ? mvnCatalog }:
let
  configEdn = writeText "config.edn" (edn.toEdnPP cfg);
  cfg = callPackage ./config.nix { inherit repository; };
in configEdn // { meta.dwn.config = cfg; }


