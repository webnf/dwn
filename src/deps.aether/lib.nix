self: super:

let
  inherit (self) lib writeScript toEdn expandRepo dependencyList defaultMavenRepos;
in {

  aetherDownloader = repoFile: repos: dependencies: overlay: writeScript "repo.edn.sh" ''
    #!/bin/sh
    exec ${self.deps.aether.dwn.binaries.prefetch} ${repoFile} \
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
    self.aetherDownloader
      (toString repositoryFile)
      repos

      (dependencyList
        (dependencies ++ fixedDependencies))

      (expandRepo overlayRepository);
}
