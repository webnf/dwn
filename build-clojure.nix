{ stdenv, lib, fetchFromGitHub, ant, jdk
, closureRepoGenerator, expandDependencies, mvnResolve, renderClasspath, defaultMavenRepos
, mavenRepos ? defaultMavenRepos
}:
let
  dependencies = [
    [ "org.clojure" "spec.alpha" "0.1.134" {
        exclusions = [
          [ "org.clojure" "clojure" ]
        ];
      } ]
    [ "org.clojure" "core.specs.alpha" "0.1.24" {
        exclusions = [
          [ "org.clojure" "clojure" ]
          [ "org.clojure" "spec.alpha" ]
        ];
      } ]
  ];
jarfile = stdenv.mkDerivation rec {
  rev = "clojure-1.9.0-beta2";
  name = "${rev}-CUSTOM.jar";
  builtName = "${rev}.jar";
  src = fetchFromGitHub {
    owner = "clojure";
    repo = "clojure";
    inherit rev;
    sha256 = "0v6gkdzrcb9pvfqhnipzqf9q81y8m3gnvm87cwz5cvlhr6791br9";
  };
  patches = [ ./compile-gte-mtime.patch ];
  closureRepo = ./clojure.repo.edn;
  passthru.closureRepoGenerator = closureRepoGenerator {
    inherit dependencies mavenRepos;
  };
  classpath = renderClasspath (lib.concatLists (
    map (mvnResolve mavenRepos)
        (expandDependencies {
          name = "clojure";
          inherit dependencies closureRepo;
         })
  ));
  nativeBuildInputs = [ ant jdk ];
  configurePhase = ''
    echo "maven.compile.classpath=$classpath" > maven-classpath.properties
  '';
  buildPhase = ''
    ant jar
  '';
  installPhase = ''
    cp $builtName $out
  '';
  meta.dwn = {
    repoEntry = {
      resolvedVersion = "1.9.0-beta2-CUSTOM";
      jar = jarfile;
      inherit dependencies;
    };
  };
};
in jarfile
