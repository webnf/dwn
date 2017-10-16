{ dwn, mvnCatalog, callPackage
, keyword
, repository ? mvnCatalog
, configFile ? callPackage ./config.edn.nix { inherit repository; } }:

dwn.componentLauncher configFile (keyword "webnf.dwn" "main")
