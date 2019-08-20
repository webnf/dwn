(import ./shell.nix).instantiate {
  dev = false;
  clj = {
    aot = [ "webnf.dwn.boot" ];
    sourceDirectories = [
      ./src/clj
    ];
  };
  cljs.sourceDirectories = [
    ./src/cljs
  ];
}
