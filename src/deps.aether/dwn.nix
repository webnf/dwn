{ pkgs, lib, ... }:

{
  optimize = true;
  mvn = {
    group = "webnf.dwn.deps";
    artifact = "aether";
    version = "0.0.3";
    dependencies = [
      ["webnf.deps" "logback" "0.2.0-alpha4"]
      ["org.apache.maven" "maven-resolver-provider" "3.6.0"]
      ["org.apache.maven.resolver" "maven-resolver-transport-file" "1.3.1"]
      ["org.apache.maven.resolver" "maven-resolver-transport-wagon" "1.3.1"]
      ["org.apache.maven.resolver" "maven-resolver-connector-basic" "1.3.1"]
      ["org.apache.maven.resolver" "maven-resolver-impl" "1.3.1"]
      ["org.apache.maven.wagon" "wagon-provider-api" "3.2.0"]
      ["org.apache.maven.wagon" "wagon-http" "3.2.0"]
      ["org.apache.maven.wagon" "wagon-ssh" "3.2.0"]
    ];
    repositoryFile = ./repo.json;
    repositoryFormat = "repo-json";
  };
  clj = {
    sourceDirectories = [ ./src ../nix.aether/src ];
    main.prefetch.namespace = "webnf.dwn.deps.aether";
    main.to-json.namespace = "webnf.dwn.deps.aether.json";
  };
}
