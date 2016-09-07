{ runCommand, jdk, classpath
, renderClasspath, resolveMvnDep
, cljCompile, jvmCompile, combinePathes }:

let jvmClasses = jvmCompile {
      name = "dwn-jvm-classes";
      classpath = renderClasspath classpath;
      sources = ./src/jvm;
    };
in combinePathes "dwn-res" [
  jvmClasses
  (cljCompile {
    name = "dwn-clj-classes";
    classpath = "${jvmClasses}:${renderClasspath classpath}";
    sources = ./src/clj;
    aot = [ "webnf.dwn.boot" ];
  })
  ./src/jvm ./src/clj
]
