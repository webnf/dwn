self: super:

let
  inherit (self) runCommand jdk renderClasspath;
in {
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

  cljCompile = { name, classpath, aot, options ? {} }: let
    boolStr = b: if b then "true" else "false";
    command = { warnOnReflection ? true,
                uncheckedMath ? false,
                disableLocalsClearing ? false,
                elideMeta ? [],
                directLinking ? false
              }: runCommand name {
                inherit classpath aot;
              } ''
        mkdir out
        CLS=`pwd`/out
        ${jdk.jre}/bin/java \
          -cp $CLS:${renderClasspath classpath} \
          -Dclojure.compile.path=$CLS \
          -Dclojure.compiler.warn-on-reflection=${boolStr warnOnReflection} \
          -Dclojure.compiler.unchecked-math=${boolStr uncheckedMath} \
          -Dclojure.compiler.disable-locals-clearing=${boolStr disableLocalsClearing} \
          "-Dclojure.compiler.elide-meta=[${toString elideMeta}]" \
          -Dclojure.compiler.direct-linking=${boolStr directLinking} \
          clojure.lang.Compile $aot
        mv $CLS $out
      '';
  in command options;

}
