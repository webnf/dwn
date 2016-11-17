{ writeText, callPackage, runCommand, dwn, edn, mvnCatalog
, configPkg ? ./config.nix
, repository ? mvnCatalog }:
let
  configEdn = writeText "config.edn" (edn.toEdnPP cfg);
  cfg = callPackage configPkg { inherit repository; };
in configEdn // { meta.dwn.config = cfg; }


