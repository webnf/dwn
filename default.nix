let

  pkgs = import <nixpkgs> {};
  inherit (pkgs) callPackage;
  jdk = pkgs.oraclejdk8;
  jre = jdk.jre;

  config = {
    dwn = {
      cwd = /home/herwig/src/database;
      host = "127.0.0.1";
      port = "1270";
      jvmOpts = [
        "-server"
        "-Xmx1024m"
        "-Xss2m"
        "-XX:+UseG1GC"
        "-XX:MaxGCPauseMillis=50"
        "-XX:+UnlockExperimentalVMOptions"
        "-XX:+DoEscapeAnalysis"
        "-XX:+UseFastAccessorMethods"
        "-XX:+AggressiveOpts"
        "-XX:+UseBiasedLocking"
        "-XX:+UseTLAB"
      ];
    };
  };

in rec {
  util = callPackage ./util.nix {};
  deps = callPackage ./deps.nix {};
  dwnPackage = callPackage ./dwn.nix {
    inherit jdk jre util;
  };
  dwn = dwnPackage config.dwn;
  juds = callPackage ./juds.nix {
    jdk = pkgs.openjdk7;
  };
  nrepl = callPackage ./nrepl.nix {} {
    dwn = {
      inherit (config.dwn) host port;
      nrepl.port = "1337";
    };
  };
}
