self: super:
{
  buildClojure = {
    version, sha256
    , classpath
    , patches ? []
  }: self.stdenv.mkDerivation rec {
    rev = "clojure-${version}";
    name = "${rev}-DWN.jar";
    builtName = "${rev}.jar";
    src = self.fetchFromGitHub {
      owner = "clojure";
      repo = "clojure";
      inherit rev sha256;
    };
    inherit patches classpath;
    nativeBuildInputs = with self; [ ant jdk ];
    configurePhase = ''
      echo "maven.compile.classpath=$classpath" > maven-classpath.properties
    '';
    buildPhase = ''
      ant jar
    '';
    installPhase = ''
      cp $builtName $out
    '';
  };
}
