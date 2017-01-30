/* { cljNsLauncher, cljCompile, mvnResolve, renderClasspath, callPackage, runCommand }:

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
*/

{ projectClasspath, mainLauncher, generateClosureRepo }:
let dependencies = [
      ["org.clojure" "clojure" "1.9.0-alpha14"]
      ["org.apache.maven" "maven-aether-provider" "3.3.9"]
      ["org.eclipse.aether" "aether-transport-file" "1.1.0"]
      ["org.eclipse.aether" "aether-transport-wagon" "1.1.0"]
      ["org.eclipse.aether" "aether-connector-basic" "1.1.0"]
      ["org.eclipse.aether" "aether-impl" "1.1.0"]
      ["org.apache.maven.wagon" "wagon-provider-api" "2.10"]
      ["org.apache.maven.wagon" "wagon-http" "2.10"]
      ["org.apache.maven.wagon" "wagon-ssh" "2.10"]
    ];
in (mainLauncher rec {
  name = "aether-downloader";
  namespace = "webnf.dwn.deps.aether";
  classpath = projectClasspath {
    name = "${name}-classpath";
    cljSourceDirs = [ ./src ]; # ../nix.data/src
    inherit dependencies;
    aot = [ namespace ];
    compilerOptions = {
      elideMeta = [":line" ":file" ":doc" ":added"];
      directLinking = true;
    };
    closureRepo = ./bootstrap-repo.edn;
  };
}) // {
  generatedClosureRepo = generateClosureRepo { inherit dependencies; };
}
