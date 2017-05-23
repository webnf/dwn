{ stdenv, fetchFromGitHub, ant, jdk, generateClosureRepo, expandDependencies, mvnResolve, renderClasspath, defaultMavenRepos
, mavenRepos ? defaultMavenRepos
, lib }:
let
  dependencies = [
    [ "org.clojure" "spec.alpha" "0.1.94" {
        exclusions = [
          [ "org.clojure" "clojure" ]
        ];
      } ]
    [ "org.clojure" "core.specs.alpha" "0.1.10" {
        exclusions = [
          [ "org.clojure" "clojure" ]
          [ "org.clojure" "spec.alpha" ]
        ];
      } ]
  ];
jarfile = stdenv.mkDerivation rec {
  rev = "clojure-1.9.0-alpha16";
  name = "${rev}-CUSTOM.jar";
  builtName = "${rev}.jar";
  src = fetchFromGitHub {
    owner = "clojure";
    repo = "clojure";
    inherit rev;
    sha256 = "1gsx9741sq1ghp4lj9kjivfzal23f55a16wyxrdalm213vx3xbrl";
  };
  patches = [ ./compile-gte-mtime.patch ];
  closureRepo = generateClosureRepo {
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
      resolvedVersion = "1.9.0-alpha16-CUSTOM";
      jar = jarfile;
      inherit dependencies;
    };
  };
};
in jarfile
