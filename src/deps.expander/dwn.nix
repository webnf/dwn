{ lib, pkgs, config, ... }:
{
  optimize = true;
  mvn = {
    group = "webnf.dwn.deps";
    artifact = "expander";
    version = "0.0.3";
    dependencies = [
      ["org.clojure" "clojure" "1.10.1"]
      [ "org.eclipse.aether" "aether-util" "1.1.0" ]
    ];
    repositoryUpdater = pkgs.writeScript "update-expander-repo" ''
      #!/bin/sh

      TMPREPO=$(mktemp /tmp/repo.edn.XXXXXX)
      trap "rm $TMPREPO" EXIT

      REPOS=${lib.escapeShellArg (pkgs.toEdn config.mvn.repos)}
      DEPS=${lib.escapeShellArg (pkgs.toEdn (lib.concatLists
        (map
          (dep: if dep ? dwn.mvn.dependencies
                then dep.dwn.mvn.dependencies
                else
                  if builtins.isAttrs dep
                  then []
                  else [ dep ])
          config.mvn.dependencies)))}

      ${pkgs.deps.aether.dwn.binaries.prefetch} "$TMPREPO" "$DEPS" "$REPOS" "{}"
      exec ${config.binaries.expand} ${toString ./deps.nix} "$TMPREPO" "$DEPS" [] [] {}
    '';
  };
  jvm.dependencyClasspath =
    lib.concatLists
      (map
        (pkgs.mvnResolve config.mvn.repos)
        (import ./deps.nix));
  clj = {
    ## disabled for bootstrapping
    customClojure = false;
    sourceDirectories = [ ./src ../nix.data/src ../nix.aether/src ];
    main.expand.namespace = "webnf.dwn.deps.expander";
  };
}
