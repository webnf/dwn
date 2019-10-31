{
  mvn = {
    group = "webnf.dwn";
    artifact = "nrepl";
    version = "0.0.3";
    dependencies = [
      ["org.clojure" "clojure" "1.10.1"]
      ["com.stuartsierra" "component" "0.4.0"]
      ["cider" "cider-nrepl" "0.22.4"]
      ["refactor-nrepl" "2.4.0"]
      ["org.clojure" "tools.logging" "0.5.0"]
    ];
    repositoryFile = ./repo.json;
  };
  clj = {
    # cider aot inhibits middleware loading
    aot = [ "webnf.dwn.nrepl" ]; # "cider.nrepl" ];
    sourceDirectories = [ ./src ];
  };
}
