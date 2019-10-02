{ config, pkgs, ... }:
{
  mvn = {
    group = "org.clojure";
    artifact = "clojure";
    version = "1.10.1";
    extension = "jar";
    dependencies = [
      ["org.clojure" "spec.alpha" "jar" "" "0.2.176" {
        exclusions = [[ "org.clojure" "clojure" ]];
      }]
      ["org.clojure" "core.specs.alpha" "jar" "" "0.2.44" {
        exclusions = [[ "org.clojure" "clojure" ]];
      }]
    ];
    repositoryFile = ./repo.json;
    repositoryFormat = "repo-json";
    jar = pkgs.buildClojure {
      inherit (config.mvn) version;
      sha256 = "0769zr58cgi0fpg02dlr82qr2apc09dg05j2bg3dg9a8xac5n1dz";
      classpath = pkgs.renderClasspath config.jvm.compileClasspath;
      patches = [ ./compile-gte-mtime.patch ];
    };
  };
  jvm.resultClasspath = [ config.mvn.jar ];
}
