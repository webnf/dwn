self: super:
let
  inherit (self) runCommand jdk renderClasspath;
in {
  jvmCompile = { name, classpath, sources }:
    runCommand name {
      inherit classpath sources;
    } ''
      mkdir -p $out
      ${jdk}/bin/javac -d $out -cp $out:${renderClasspath classpath} `find $sources -name '*.java'`
    '';

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
