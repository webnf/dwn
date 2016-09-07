let
  clj = import ./.;
in {

  cljVersion = clj.launcher {
    name = "clojure-version-printer";
    env = clj.baseEnv;
    codes = [ ''
      (println *clojure-version*)
    '' ];
  };

}
