{
  optimize = true;
  mvn = {
    group = "webnf.dwn";
    artifact = "lein.reader";
    version = "0.0.3";
    dependencies = [
      ["leiningen" "leiningen" "2.9.1"]
    ];
    repositoryFile = ./repo.json;
  };

  clj = {
    sourceDirectories = [ ./src ../nix.data/src ];
    aot = [ "webnf.dwn.lein.reader" ];
    main.lein2nix.namespace = "webnf.dwn.lein.reader";
  };
}
