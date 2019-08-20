{ stdenv, lib, fetchFromGitHub, ant, jdk, writeScript, nix, mvnReader
, closureRepoGenerator, expandDependencies, mvnResolve, renderClasspath, defaultMavenRepos
, mavenRepos ? defaultMavenRepos
}:
let
  dependencies1 = import ./dependencies.nix;
  dependencies = map (d: d ++ [{
    exclusions = [
      [ "org.clojure" "clojure" ]
    ] ++ (map (lib.take 2) dependencies1);
  }]) dependencies1;
  version = "1.10.1";
  jarfile = stdenv.mkDerivation rec {
    rev = "clojure-${version}";
    name = "${rev}-DWN.jar";
    builtName = "${rev}.jar";
    src = fetchFromGitHub {
      owner = "clojure";
      repo = "clojure";
      inherit rev;
      sha256 = "0769zr58cgi0fpg02dlr82qr2apc09dg05j2bg3dg9a8xac5n1dz";
    };
    patches = [ ./compile-gte-mtime.patch ];
    closureRepo = ./clojure.repo.edn;
    passthru.closureRepoGenerator = closureRepoGenerator {
      inherit dependencies mavenRepos closureRepo;
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
    passthru.dependencyUpdater = writeScript "clojure-dependency-updater" ''
      #!${stdenv.shell} -e
      exec ${mvnReader}/bin/mvn2nix pr-compile-deps https://repo1.maven.org/maven2/org/clojure/clojure/${version}/clojure-${version}.pom > ${toString ./dependencies.nix}
    '';

  };
in jarfile
