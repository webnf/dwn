self: super:

{
  jvmCompile = { name, classpath, sources }:
    self.runCommand name {
      inherit classpath sources;
    } ''
      mkdir -p $out
      ${self.jdk}/bin/javac -d $out -cp $out:${self.renderClasspath classpath} `find $sources -name '*.java'`
    '';
}
