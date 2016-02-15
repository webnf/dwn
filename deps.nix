{ fetchurl, lib }:
let
  dotToSlash = s: builtins.replaceStrings ["."] ["/"] s;

  mvnRepo = base: group: id: version: let
      groupPath = dotToSlash group;
    in "${base}/${groupPath}/${id}/${version}/${id}-${version}.jar";

  mvnCentral = mvnRepo "http://central.maven.org/maven2";
  clojars = mvnRepo "https://clojars.org/repo";

  logbackDep = id: mvnCentral "ch.qos.logback" id "1.1.3";
  slf4jDep = id: mvnCentral "org.slf4j" id "1.7.13";

  descriptors = {
    clojure = {
      url = mvnCentral "org.clojure" "clojure" "1.8.0";
      sha256 = "1a30sdpn1rr50w7qfz6pn3z5i43fjq3z9qm1aa4cd9piwhgpy6h6";
    };
    logback-classic = {
      url = logbackDep "logback-classic";
      sha1 = "5w4ccqydg1kpy1gjfnrnrw0lykzpc0nr";
    };
    logback-core = {
      url = logbackDep "logback-core";
      sha1 = "ayqrkg6wy3n9805lh537dg6vy94j1h73";
    };
    slf4j-api = {
      url = slf4jDep "slf4j-api";
      sha1 = "4v074lmjhzsd7l6sp5wr6jlgbg131kvz";
    };
    log4j-over-slf4j = {
      url = slf4jDep "log4j-over-slf4j";
      sha1 = "aflxyfxqbwmixmg1yxmvmzx6fd86ix5m";
    };
    jcl-over-slf4j = {
      url = slf4jDep "jcl-over-slf4j";
      sha1 = "3m4l6az5dbvjbljja5i84hafw51253fp";
    };
    jul-to-slf4j = {
      url = slf4jDep "jul-to-slf4j";
      sha1 = "0ldwvxnjb8z57s9mbq2cgzp5dnc9wxa3";
    };
    servlet-api = {
      url = mvnCentral "javax.servlet" "javax.servlet-api" "3.1.0";
      sha1 = "gjzhaj9g8dcvx17sna21fxcpah3kvmiw";
    };
    mail-api = {
      url = mvnCentral "javax.mail" "javax.mail-api" "1.5.5";
      sha1 = "z0vynivm9b7hhpbv1ndv6wr8bd3z86n2";
    };
    mail = {
      url = mvnCentral "com.sun.mail" "javax.mail" "1.5.5";
      sha1 = "ffcd34b5de820f35bcc9303649cf6ab2c65ad44e";
    };
    toolsLogging = {
      url = mvnCentral "org.clojure" "tools.logging" "0.3.1";
      sha1 = "d8342cb0b6825cd12115cc1a9ccef988484478b2";
    };
    toolsNrepl = {
      url = mvnCentral "org.clojure" "tools.nrepl" "0.2.12";
      sha1 = "a1a0mf0bwqm523fi9hz2b6ss9ilvxd3j";
    };
    ciderNrepl = {
      url = clojars "cider" "cider-nrepl" "0.10.2";
      sha256 = "0a63ah3hbgvki72knffhv2qc2qwdbkyxrvdrrxl5napi74fvhs11";
    };
    refactorNrepl = {
      url = clojars "refactor-nrepl" "refactor-nrepl" "2.1.0-alpha1";
      sha1 = "ee05e8125a7c53b4bd376a1eb6cac587585419c3";
    };
    stuartsierraComponent = {
      url = clojars "com.stuartsierra" "component" "0.3.1";
      sha1 = "8816628263c02da1e50c634c9eff085c14514b60";
    };
    stuartsierraDependency = {
      url = clojars "com.stuartsierra" "dependency" "0.2.0";
      sha1 = "9e192005144258ea82ee8459bf2afeda88d45a36";
    };
    dynapath = {
      url = clojars "org.tcrawley" "dynapath" "0.2.3";
      sha1 = "1hpdindwh73h0qdka6h31nj84l55lr0w";
    };
    jnrPosix = {
      url = mvnCentral "com.github.jnr" "jnr-posix" "3.0.23";
      sha1 = "638kzaln85ln1rmwifkb89sin6vs1al1";
    };
    jnrConstants = {
      url = mvnCentral "com.github.jnr" "jnr-constants" "0.9.0";
      sha1 = "lvfx9d3lqvkbb0kfhc0dak582x76i538";
    };
    jnrFfi = {
      url = mvnCentral "com.github.jnr" "jnr-ffi" "2.0.7";
      sha1 = "wfb53m1924n4qq7k5pdfp0x2nmdqr5ph";
    };
    jnrJffi = {
      url = mvnCentral "com.github.jnr" "jffi" "1.2.10";
      sha1 = "fnlsm89gb45z9gmz97qc6ss5hcidp3ym";
    };
  };
  jars = lib.mapAttrs (_: fetchurl) descriptors;
in jars // (with jars; {
  sets = {
    ssCmp = [ stuartsierraComponent stuartsierraDependency ];
    jnrPosix = [ jnrPosix jnrConstants jnrFfi jnrJffi ];
    logback = [ logback-classic logback-core slf4j-api
                log4j-over-slf4j jcl-over-slf4j jul-to-slf4j];
    cider = [ toolsNrepl ciderNrepl refactorNrepl dynapath ];
  };
})
