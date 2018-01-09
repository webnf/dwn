{ stdenv, lib, fetchFromGitHub, ant, jdk
, closureRepoGenerator, expandDependencies, mvnResolve, renderClasspath, defaultMavenRepos
, mavenRepos ? defaultMavenRepos
}:
let
  dependencies = [
    [ "org.clojure" "spec.alpha" "0.1.143" {
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
  rev = "clojure-1.9.0";
  name = "${rev}-DWN.jar";
  builtName = "${rev}.jar";
  src = fetchFromGitHub {
    owner = "clojure";
    repo = "clojure";
    inherit rev;
    sha256 = "0gwb9cz9fvi183angv1j3bjdxsm6aa7k7dz71q6y48sykyyjsfpc";
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
  passthru.dwn = {
    group = "org.clojure";
    artifact = "clojure";
    version = "1.9.0";
    resolvedVersion = "1.9.0-DWN";
    extension = "jar";
    classifier = "";
    jar = jarfile;
    inherit dependencies;
    expandedDependencies = dependencies;

  };
  meta.dwn = (lib.warn "Deprecated usage of clojure.meta.dwn ; use clojure.dwn instead" {
    group = "org.clojure";
    name = "clojure";
    version = "1.9.0-DWN";
    repoEntry = {
      resolvedVersion = "1.9.0-DWN";
      jar = jarfile;
      inherit dependencies;
    };
  });
};
in jarfile
