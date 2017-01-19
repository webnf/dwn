{ cljNsLauncher, cljCompile, mvnResolve, renderClasspath, callPackage }:

let bootstrap-classpath = map mvnResolve (import ./classpath.bootstrap.nix);

in cljNsLauncher {

  name = "dwn-deps-expander";
  classpath = [
      ./src ../nix.data/src
      (cljCompile {
        name = "dwn-deps-expander-classes";
        classpath = renderClasspath ([ ./src ../nix.data/src ] ++ bootstrap-classpath);
        aot = [ "webnf.dwn.deps.expander" ];
        options = {
          elideMeta = "'[:line :file :doc :added]'";
          directLinking = "true";
        };
      })
    ] ++ bootstrap-classpath;
  namespace = "webnf.dwn.deps.expander";

}
