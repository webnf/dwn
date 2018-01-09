{ classpathFor, shellBinder, closureRepoGenerator, devMode }:

(shellBinder.mainLauncher rec {
  name = "aether-downloader";
  namespace = "webnf.dwn.deps.aether";
  #jvmArgs = [
  #  "-Xss8M"
  #];
  classpath = classpathFor {
    name = "${name}-classpath";
    inherit devMode;
    cljSourceDirs = [ ./src ../nix.aether/src ];
    ## don't update ./deps.bootstrap.nix it will be copied from ./deps.nix
    dependencies = import ./deps.bootstrap.nix;
    aot = [ namespace ];
    compilerOptions = {
      elideMeta = [":line" ":file" ":doc" ":added"];
      directLinking = true;
    };
    closureRepo = ./bootstrap-repo.edn;
  };
}) // {
  closureRepoGenerator = closureRepoGenerator {
    ## UPDATE DEPENDENCIES in ./deps.nix
    dependencies = import ./deps.nix;
  };
}
