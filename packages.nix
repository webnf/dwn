self: super:
let
  inherit (self) callPackage;
in rec {
  defaultMavenRepos = [ http://repo1.maven.org/maven2
                        https://clojars.org/repo ];

  edn = callPackage ./src/nix/lib/edn.nix {};
  inherit (edn) asEdn toEdn toEdnPP;
  inherit (edn.syntax) tagged hash-map keyword-map list vector set symbol keyword string int bool nil;
  inherit (edn.data) get get-in eq nth nix-str nix-list extract;

  inherit (callPackage ./src/nix/lib/compile.nix {}) jvmCompile cljCompile classesFor;
  inherit (callPackage ./src/nix/lib/lib-project.nix {})
    sourceDir subProjectOverlay subProjectFixedVersions
    classpathFor artifactClasspath dependencyClasspath;
  inherit (callPackage ./src/nix/lib/descriptor.nix {})
    projectDescriptor projectNsLaunchers projectComponents artifactDescriptor;
  inherit (callPackage ./src/nix/lib/shell-binder.nix {}) renderClasspath shellBinder;
  inherit (callPackage ./deps.expander/lib.nix {}) depsExpander expandDependencies;
  inherit (callPackage ./deps.aether/lib.nix {}) aetherDownloader closureRepoGenerator;
  inherit (callPackage ./src/nix/lib/repository.nix {})
    mergeRepos descriptorPaths mapRepoVals filterDirs
    mavenMirrors mvnResolve getRepo getRepoCoord unwrapCoord;
  inherit (callPackage ./src/nix/lib/leiningen.nix {}) fromLein;

  clojure = callPackage ./clojure { };
  deps = {
    expander = instantiatePkg ./deps.expander/dwn.nix;
    aether = instantiatePkg ./deps.aether/dwn.nix;
  };
  dwn = instantiatePkg ./dwn.nix;
  nrepl = instantiatePkg ./nrepl/dwn.nix;
  lein.reader = callPackage ./lein.reader/project.nix { devMode = false; };
  mvn.reader = callPackage ./mvn.reader/project.nix { devMode = true; };
  juds = callPackage ./juds.nix {};
  dwnTool = callPackage ./dwn-tool.nix {};

  ## Module stuff
  
  instantiateWith = moduleList: config:
    (instantiateWithBase moduleList { config.dwn = config; })
    // {
      overrideConfig = cfn:
        instantiateWith moduleList (cfn config);
    };
  instantiateWithBase = moduleList: module: callPackage ({ lib, pkgs }:
    (lib.evalModules {
      modules = moduleList ++ [{
        config._module.args.pkgs = pkgs;
      } module];
    }).config.result
  ) { };

  instantiatePkgWith = moduleList: pkg: instantiateWithBase
    moduleList
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

  instantiate = instantiateWith [ ./clojure/module.nix ];
  instantiatePkg = instantiatePkgWith [ ./clojure/module.nix ];

}
