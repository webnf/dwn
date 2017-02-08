{ lib, compiledClasspath, mainLauncher, mvnResolve, defaultMavenRepos }:

mainLauncher rec {
  name = "dependency-expander";
  namespace = "webnf.dwn.deps.expander";

  classpath = compiledClasspath {
    name = "${name}-classpath";
    cljSourceDirs = [ ./src ../nix.data/src ];
    dependencyClasspath = lib.concatLists (map (mvnResolve defaultMavenRepos)
                              (import ./classpath.bootstrap.nix));
    aot = [ namespace ];
    compilerOptions = {
      elideMeta = [":line" ":file" ":doc" ":added"];
      directLinking = true;
    };
  };
}
