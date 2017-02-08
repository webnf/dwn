{ project }:

project {

  name = "nrepl-cmp";

  cljSourceDirs = [ ./nrepl-cmp ];
  dependencies = [
    ["org.clojure" "clojure" "1.9.0-alpha14"]
    ["cider" "cider-nrepl" "0.14.0"]
    ["refactor-nrepl" "2.3.0-SNAPSHOT"]
  ];

}
