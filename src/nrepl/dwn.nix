{
  mvn = {
    group = "webnf.dwn";
    artifact = "nrepl";
    version = "0.0.2";
    dependencies = [
      ["org.clojure" "clojure" "1.10.1"]
      ["com.stuartsierra" "component" "0.4.0"]
      ["cider" "cider-nrepl" "0.21.1"]
      ["refactor-nrepl" "2.4.0"]
      ["org.clojure" "tools.logging" "0.4.1"]
    ];
    repositoryFile = ./repo.edn;
  };
  clj = {
    aot = [ "webnf.dwn.nrepl" "cider.nrepl" ];
    sourceDirectories = [ ./src ];
  };
}
