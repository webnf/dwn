{ lib, writeScript, callPackage
, toEdn
, defaultMavenRepos
, expandRepo, dependencyList, deps
}:

rec {

  aetherDownloader = repoFile: repos: dependencies: overlay: writeScript "repo.edn.sh" ''
    #!/bin/sh
    exec ${deps.aether.dwn.binaries.prefetch} ${repoFile} \
      ${lib.escapeShellArg (toEdn dependencies)} \
      ${lib.escapeShellArg (toEdn repos)} \
      ${lib.escapeShellArg (toEdn overlay)}
  '';

  closureRepoGenerator =
    { dependencies ? []
    , repos ? defaultMavenRepos
    , fixedDependencies ? []
    , overlayRepository ? {}
    , repositoryFile
    , ... }:
    aetherDownloader
      (toString repositoryFile)
      repos

      (dependencyList
        (dependencies ++ fixedDependencies))

      (expandRepo overlayRepository);
}
