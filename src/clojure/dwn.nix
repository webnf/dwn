{ config, pkgs, lib, ... }:
let version = "1.10.1"; in
{
  mvn = {
    group = "org.clojure";
    artifact = "clojure";
    version = "${version}-DWN";
    extension = lib.mkForce "jar";
    dependencies = [
      ["org.clojure" "spec.alpha" "jar" "" "0.2.176"]
      ["org.clojure" "core.specs.alpha" "jar" "" "0.2.44"]
    ];
    repositoryFile = ./repo.json;
    repositoryFormat = "repo-json";
    jar = pkgs.buildClojure {
      inherit version;
      sha256 = "0769zr58cgi0fpg02dlr82qr2apc09dg05j2bg3dg9a8xac5n1dz";
      classpath = pkgs.renderClasspath config.jvm.compileClasspath;
      patches = [ ./compile-gte-mtime.patch ];
    };
  };
  jvm.resultClasspath = [ config.mvn.jar ];
}
