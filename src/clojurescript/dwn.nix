{
  mvn = {
    group = "webnf.dwn";
    artifact = "cljs";
    version = "0.0.1";
    dependencies = [
      ["org.clojure" "clojurescript" "1.10.520"]
    ];
    repositoryFile = ./repo.edn;
  };
  
  clj = {
    aot = [ "webnf.dwn.cljs" ];
    sourceDirectories = [ ./src ];
    main.cljs-build.namespace = "webnf.dwn.cljs";
  };

}
