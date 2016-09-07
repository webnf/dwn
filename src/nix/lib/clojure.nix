{ newScope, jdk, lib, writeScript, fetchurl, runCommand }:
let callPackage = newScope thisns;
    thisns = { inherit callPackage; } // rec {

  launcher = { env, codes, name ? "runnable-launcher" }: writeScript name ''
    #!/bin/sh
    exec ${jdk.jre}/bin/java \
      -cp ${renderClasspath (buildClasspath env)} \
      clojure.main -e "$(cat <<CLJ62d3c200-34d4-49e5-a64d-f6eaf59b4715
    ${lib.concatStringsSep "\n\n;; ----\n\n" codes}
    CLJ62d3c200-34d4-49e5-a64d-f6eaf59b4715
    )"
  '';

  cljNsLauncher = { name, env, namespace
                  , prefixArgs ? [], suffixArgs ? [] }: writeScript name ''
    #!/bin/sh
    exec ${jdk.jre}/bin/java \
      -cp ${renderClasspath (buildClasspath env)} \
      clojure.main -m '${namespace}' \
      ${toString prefixArgs} \
      "$@" \
      ${toString suffixArgs}
  '';
    

  baseEnv = {
    classpath = [ ["org.clojure" "clojure"] ];
  };

  jvmCompile = { name, classpath, sources }:
    runCommand name {
      inherit classpath sources;
    } ''
      mkdir -p $out
      ${jdk}/bin/javac -d $out -cp $out:$classpath `find $sources -name '*.java'`
    '';

  cljCompile = { name, classpath, aot, sources, options ? {} }:
    runCommand name {
      inherit classpath sources aot;
    } ''
      mkdir -p $out
      ${jdk.jre}/bin/java \
        -cp $out:$sources:$classpath \
        -Dclojure.compile.path=$out \
        -Dclojure.compiler.warn-on-reflection=${options.warnOnReflection or "true"} \
        -Dclojure.compiler.unchecked-math=${options.uncheckedMath or "false"} \
        -Dclojure.compiler.disable-locals-clearing=${options.disableLocalsClearing or "false"} \
        -Dclojure.compiler.elide-meta="${options.elideMeta or "[]"}" \
        -Dclojure.compiler.direct-linking=${options.directLinking or "false"} \
        clojure.lang.Compile $aot
    '';

  combinePathes = name: pathes: runCommand name { inherit pathes; } ''
    mkdir -p out
    for p in $pathes; do
      cp -nR $p/${"*"} out
      chmod -R +w out
    done
    cp -R out $out
  '';

  ## Maven

  resolveDep = cat: art: let
    version = if 3 == lib.length art then lib.elemAt art 2 else "DEFAULT";
    name = lib.elemAt art 1;
    group = lib.elemAt art 0;
    descriptor = lib.getAttr version (
     lib.getAttr
      ( lib.elemAt art 1 )
      ( lib.getAttr group cat ) );
    tag = lib.elemAt descriptor 0;
  in
    if tag == "mvn" then
      fetchurl {
        name = "${name}-${version}.jar";
        urls = mavenMirrors group name version;
        sha256 = lib.elemAt descriptor 1;
      }
    else if tag == "nix" then
      callPackage (lib.elemAt descriptor 1) {}
    else if tag == "alias" then
      resolveDep cat (
      if 2 == lib.length descriptor then
        [ group name (lib.elemAt descriptor 1) ]
      else
        [ (lib.elemAt descriptor 1)
          (lib.elemAt descriptor 2)
          (lib.elemAt descriptor 3) ]
      )
    else throw "unknown op tag [${descriptor}]" ;

  resolveMvnDep = e:
    if lib.isList e
    then resolveDep mvnCatalog e
    else e;

  buildClasspath = { classpath }:
    map resolveMvnDep classpath;

  mvnCatalog = import ./repository.nix;

  mavenMirrors = group: name: version: let
    dotToSlash = lib.replaceStrings [ "." ] [ "/" ];
    mvnPath = baseUri: "${baseUri}/${dotToSlash group}/${name}/${version}/${name}-${version}.jar";
  in map mvnPath [
    http://repo1.maven.org/maven2
    https://clojars.org/repo
  ];

  ## utilities / data structures

  renderClasspath = classpath: lib.concatStringsSep ":" classpath;

  compEnv = e1: e2: {
    ## FIXME check classpathes for version conflicts
    ## FIXME merge classpaths explicitly
    classpath = e1.classpath ++ e2.classpath;
    ## FIXME check reader tags for conflicts
    dataReaders = e1.dataReaders // e2.dataReaders;
  };

  runnable = env: codes: {
    inherit env codes;
    before = nr: runnable
      ( compEnv env nr.env )
      ( codes ++ nr.codes );
  };
  
};
in thisns
