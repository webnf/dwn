{ lib, shellBinder
, keyword-map, symbol, keyword, string, tagged
, nix-list, nix-str, get, extract }:

rec {

  container = tagged (symbol "webnf.dwn" "container");
  component = tagged (symbol "webnf.dwn" "component");
  ns-launcher = tagged (symbol "webnf.dwn" "ns-launcher");

  /*
  componentLauncher = cfgFile: componentKey:
    let
      inherit (cfgFile.meta.dwn) config;
      launcherConfig = extract (symbol "webnf.dwn" "ns-launcher")
                               (get config componentKey);
      containerConfig = extract (symbol "webnf.dwn" "container")
                                (get config (get launcherConfig (keyword null "container")));
    in cljNsLauncher {
      name = "launcher";
      classpath = lib.concatMap
        (e:
          let
            sourceDirs = get e (keyword null "source-dirs");
            jarFile = get e (keyword null "jar-file");
          in if isNull sourceDirs
             then [ (nix-str jarFile) ]
             else map nix-str (nix-list sourceDirs))
        (nix-list (get containerConfig (keyword null "classpath")));
      namespace = nix-str (get launcherConfig (keyword null "main"));
      suffixArgs = [ cfgFile ];
    };
*/
}
      
