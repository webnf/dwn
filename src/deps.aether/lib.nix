{ lib, writeScript, callPackage
, toEdn
, defaultMavenRepos
, filterDirs, deps
}:

rec {

  aetherDownloader = repoFile: repos: dependencies: overlay: writeScript "repo.edn.sh" ''
    #!/bin/sh
    exec ${deps.aether.dwn.binaries.prefetch} ${repoFile} \
      ${lib.escapeShellArg (toEdn dependencies)} \
      ${lib.escapeShellArg (toEdn repos)} \
      ${lib.escapeShellArg (toEdn overlay)}
  '';

  closureRepoGenerator = { dependencies ? []
                         , mavenRepos ? defaultMavenRepos
                         , fixedVersions ? []
                         , overlayRepo ? {}
                         , closureRepo
                         , ... }:
    aetherDownloader
      (toString closureRepo)
      mavenRepos
      (lib.concatLists
        (map
          (dep:
            if builtins.isList dep
            then [ dep ]
            else dep.dwn.mvn.dependencies)
          (dependencies ++ fixedVersions)))
      (filterDirs overlayRepo);

}
