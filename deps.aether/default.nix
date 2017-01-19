{ cljNsLauncher, cljCompile, mvnResolve, renderClasspath, callPackage, runCommand }:

let bootstrap-classpath = map mvnResolve (import (runCommand "dwn-deps-aether-classpath" {
      expander = callPackage ../deps.expander { };  
    } ''
      exec $expander $out ${./deps.edn} ${./bootstrap-repo.edn}
    ''));
in cljNsLauncher {

  name = "dwn-deps-aether";
  classpath = [
      ./src # ../nix.data/src
      (cljCompile {
        name = "dwn-deps-aether-classes";
        classpath = renderClasspath ([ ./src # ../nix.data/src
           ] ++ bootstrap-classpath);
        aot = [ "webnf.dwn.deps.aether" ];
        options = {
          elideMeta = "'[:line :file :doc :added]'";
          directLinking = "true";
        };
      })
    ] ++ bootstrap-classpath;
  namespace = "webnf.dwn.deps.aether";
}
