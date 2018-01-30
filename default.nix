{ jdk, newScope
, devMode ? false
, varDirectory ? "/tmp/dwn.var"
, clojureLib ? null
}:
let callPackage = newScope thisns;
    thisns = { inherit callPackage; } // { # clojureLib // {
      inherit jdk;
      dwnConfig = {
        inherit devMode varDirectory;
      };
      clojureLib = if isNull clojureLib then
          callPackage ./src/nix/lib/default.nix {}
        else
          clojureLib;
    };
in callPackage ./packages.nix { }
