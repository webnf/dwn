{ newScope, dwnConfig, clojureLib }:
let
  callPackage = newScope thisns;
  thisns = clojureLib // rec {
    inherit dwnConfig callPackage;
    inherit (dwnConfig) devMode;

    callProject = project: args:
      (callPackage project args) (dwnConfig.binder or clojureLib.shellBinder);

    clojure = callPackage ./build-clojure.nix { };

    dwn = callProject ./project.nix { };
    dwnSystemd = callPackage ./src/systemd {
      dwnLauncher = dwn.meta.dwn.launchers.boot;
      inherit (dwnConfig) varDirectory;
    };
    nrepl = callProject ./nrepl-project.nix {
      inherit (dwn.meta.dwn) providedVersions;
    };
    depsExpander = callPackage ./deps.expander {};
    depsAether = callPackage ./deps.aether {};
    juds = callPackage ./juds.nix {};
  };
in thisns
