{
  optimize = true;
  mvn = {
    group = "webnf.dwn";
    artifact = "mvn.reader";
    version = "0.0.3";
    dependencies = [
      ["org.apache.maven" "maven-model" "3.6.2"]
    ];
    repositoryFile = ./repo.json;
  };
  # nrepl.port = 4050;
  clj = {
    sourceDirectories = [ ./src ../nix.data/src ];
    aot = [ "webnf.dwn.mvn.reader" ];
    main.mvn2nix.namespace = "webnf.dwn.mvn.reader";
  };
}
