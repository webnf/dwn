{ newScope, dwnConfig, clojureLib, lib, writeText, pkgs }:
let
  mkUnits = callPackage ./src/systemd/gen.nix { };

  callPackage = newScope thisns;
  thisns = clojureLib // rec {
    inherit dwnConfig callPackage mkUnits;
    inherit (dwnConfig) devMode;
    inherit (leiningenLib) fromLein;

    callProject = project: args:
      # (callPackage project args) (dwnConfig.binder or clojureLib.shellBinder);
      lib.warn "DEPRECATED usage of callProject, just use callPackage"
               (callPackage project args);

    instantiateWith = moduleList: config:
      (instantiateWithBase moduleList { config.dwn = config; })
      // {
        overrideConfig = cfn:
          instantiateWith moduleList (cfn config);
      };
    instantiate = instantiateWith (import ./module-list.nix);
    instantiateWithBase = moduleList: module: callPackage ({ lib, pkgs }:
      (lib.evalModules {
        modules = moduleList ++ [{
          config._module.args.pkgs = pkgs;
        } module];
      }).config.result
    ) { pkgs = pkgs // thisns; };

    instantiatePkg = pkg: instantiateWithBase
      (import ./module-list.nix)
      ({ config, pkgs, lib, ... }:
        let expr = import pkg;
            dwn = if builtins.isFunction expr
                  then expr {
                    inherit pkgs lib;
                    config = config.dwn;
                  }
                  else expr;
        in { inherit dwn; }
      );

    clojure = callPackage ./clojure { inherit mvnReader; };
    leiningenLib = callPackage ./src/nix/lib/leiningen.nix {};

    dwn = callPackage ./project.nix { };
    dwnSystemd = callPackage ./src/systemd {
      dwnLauncher = dwn.meta.dwn.launchers.boot;
      inherit (dwnConfig) varDirectory;
    };
    nrepl = instantiateWith [ ./clojure/module.nix ] (import ./nrepl/dwn.nix);
    leinReader = callPackage ./lein.reader/project.nix { devMode = false; };
    mvnReader = callPackage ./mvn.reader/project.nix { devMode = true; };
    deps = {
      expander = callPackage ./deps.expander { devMode = false; };
      expanderNg = instantiatePkg ./deps.expander/dwn.nix;
      aether = callPackage ./deps.aether { devMode = false; };
      aetherNg = instantiatePkg ./deps.aether/dwn.nix;
    };
    juds = callPackage ./juds.nix {};
    descriptors = lib.listToAttrs (map (name:
        lib.nameValuePair
          name
          (writeText name
            (lib.getAttr name thisns).meta.dwn.descriptor))
      [ "dwn" "nrepl" ]);
    dwnTool = callPackage ./dwn-tool.nix {};
    sysTD = let
        launcher = dwn.meta.dwn.launchers.boot;
        socket = "${dwnConfig.varDirectory}/dwn.socket";
    in mkUnits {
      services = {
        dwn = {
          description = "`dwn` clojure runner";
          serviceConfig = {
            Type="simple";
            ExecStart="${launcher} ${socket}";
            ExecPostStart="/bin/sh -c 'while [ ! -S ${socket} ]; do sleep 0.2; done'";
          };
        };
      };
    };
  };
in thisns
