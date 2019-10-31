{ pkgs, lib, ... }:

{
  optimize = true;
  mvn = {
    group = "webnf.dwn.deps";
    artifact = "aether-bootstrap";
    version = "0.0.4";
    dependencies = [
      ["webnf.deps" "logback" "0.2.0-alpha4"]
      ["org.apache.maven" "maven-resolver-provider" "3.6.2"]
      ["org.apache.maven" "maven-core" "3.6.2"]
      ["org.apache.maven" "maven-settings-builder" "3.6.2"]
      ["org.apache.maven.resolver" "maven-resolver-api" "1.4.1"]
      ["org.apache.maven.resolver" "maven-resolver-spi" "1.4.1"]
      ["org.apache.maven.resolver" "maven-resolver-transport-file" "1.4.1"]
      ["org.apache.maven.resolver" "maven-resolver-transport-http" "1.4.1"]
      ["org.apache.maven.resolver" "maven-resolver-transport-wagon" "1.4.1"]
      ["org.apache.maven.resolver" "maven-resolver-connector-basic" "1.4.1"]
      ["org.apache.maven.resolver" "maven-resolver-impl" "1.4.1"]
      ["org.apache.maven.resolver" "maven-resolver-util" "1.4.1"]
      ["org.apache.maven.wagon" "wagon-provider-api" "3.3.3"]
      ["org.apache.maven.wagon" "wagon-http" "3.3.3"]
      ["org.apache.maven.wagon" "wagon-ssh" "3.3.3"]
      ["org.codehaus.plexus" "plexus-utils" "3.3.0"]
    ];
    repositoryFile = ./repo.json;
  };
  clj = {
    sourceDirectories = [ ./src ../nix.aether/src ];
    main.prefetch.namespace = "webnf.dwn.deps.aether";
    main.to-json.namespace = "webnf.dwn.deps.aether.json";
  };
}
