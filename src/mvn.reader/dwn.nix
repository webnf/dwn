{
  optimize = true;
  mvn = {
    group = "webnf.dwn";
    artifact = "mvn.reader";
    version = "0.0.2";
    dependencies = [
      ["org.apache.maven" "maven-model" "3.6.1"]
    ];
    repositoryFile = ./repo.edn;
  };
  # nrepl.port = 4050;
  clj = {
    sourceDirectories = [ ./src ../nix.data/src ];
    aot = [ "webnf.dwn.mvn.reader" ];
    main.mvn2nix.namespace = "webnf.dwn.mvn.reader";
  };
}
