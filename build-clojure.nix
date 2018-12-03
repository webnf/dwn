{ stdenv, lib, fetchFromGitHub, ant, jdk
, closureRepoGenerator, expandDependencies, mvnResolve, renderClasspath, defaultMavenRepos
, mavenRepos ? defaultMavenRepos
}:
let
  dependencies = [
    [ "org.clojure" "spec.alpha" "0.2.176" {
        exclusions = [
          [ "org.clojure" "clojure" ]
        ];
      } ]
    [ "org.clojure" "core.specs.alpha" "0.2.44" {
        exclusions = [
          [ "org.clojure" "clojure" ]
          [ "org.clojure" "spec.alpha" ]
        ];
      } ]
  ];
  version = "1.10.0-RC2";
  jarfile = stdenv.mkDerivation rec {
    rev = "clojure-${version}";
    name = "${rev}-DWN.jar";
    builtName = "${rev}.jar";
    src = fetchFromGitHub {
      owner = "clojure";
      repo = "clojure";
      inherit rev;
      sha256 = "00bsn41nnkrq6p7jfxg8z1zqqppbrpv09ki5gv35jb0iw67mdl0m";
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
      resolvedVersion = "${version}-DWN";
      extension = "jar";
      classifier = "";
      jar = jarfile;
      inherit version dependencies;
      expandedDependencies = dependencies;
    };
  };
in jarfile
