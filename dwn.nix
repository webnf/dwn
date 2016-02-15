{ callPackage, runCommand, lib, fetchurl, dysnomia, jdk, jre, util, pkgs,
  version ? import ./VERSION }:
{ cwd ? ".", host, port, jvmOpts ? [], ... }:
with util;
let

  dotToSlash = s: lib.replaceStrings ["."] ["/"] s;

  classPath = with mvnDeps; [
    clojure servlet-api toolsLogging dynapath mail
  ] ++ sets.ssCmp ++ sets.logback; ## ++ sets.jnrPosix;

/* in writeScriptBin "dwn" ''
  #!/bin/sh
  exec ${jre}/bin/java \
   -cp ${./src}:${lib.concatStringsSep ":" classpath} \
   ${lib.concatStringsSep " " jvmOpts} \
   clojure.main -m webnf.dwn "$@"
'' */
  java = "${jre}/bin/java";
  javaSources = [
    "webnf.jvm.classloader.CustomClassLoader"
    "webnf.jvm.classloader.IClassLoader"
    "webnf.jvm.security.ISecurityManager"
    "webnf.jvm.security.SecurityManager"
    "webnf.jvm.threading.ThreadGroup"
  ];
in runCommand "dwn-${version}" {
  inherit java jvmOpts cwd host port;
  inherit (pkgs) zsh socat;
  classPath = lib.concatStringsSep ":" classPath;
  javaSources = map (src: "${./src}/${dotToSlash src}.java") javaSources;
  buildInputs = [ jdk ];
} ''
  mkdir -p $out/target $out/bin $out/share/dwn
  export target=$out/target/
  substituteAll ${./start.sh.in} $out/bin/dwn-server
  substituteAll ${./command-runner.sh.in} $out/bin/dwn-client
  cat > $out/bin/dwn-wait-server <<EOF
  #!/bin/sh
  while true; do
    echo "[:echo]" | $socat/bin/socat - tcp-connect:$host:$port; EXIT="\$?"
    if [ "\$EXIT" == "0" ]; then
      echo "Server appeared on $host:$port"
      exit 0
    fi
    echo "Waiting for server: \$EXIT"
    sleep 1
  done
  EOF
  chmod +x $out/bin/dwn-server $out/bin/dwn-client $out/bin/dwn-wait-server
  mkdir classes
  javac -cp "$out/target/:$classPath" -d classes $javaSources
  cp -rT  classes $out/target
  cp -rT ${./src} $out/target
  cat > $out/share/dwn/nrepl.edn <<EOF
  ${dwnComponent ":dwn/nrepl" ":mixin" "webnf.dwn.nrepl/nrepl" (with mvnDeps; [
      (sourceDir ./nrepl-cmp) clojure toolsLogging
    ] ++ sets.ssCmp ++ sets.cider)}
  EOF
''
