self: super:

let
  inherit (self)
    lib writeScript toEdn expandRepo dependencyList defaultMavenRepos aetherDownloader
    coordinateFor;
  inherit (self.deps) aether;
in {
  aetherDownloader = repoFile: repos: dependencies: overlay: writeScript "repo.edn.sh" ''
    #!/bin/sh
    exec ${aether.dwn.binaries.prefetch} ${repoFile} \
      ${lib.escapeShellArg (toEdn dependencies)} \
      ${lib.escapeShellArg (toEdn repos)} \
      ${lib.escapeShellArg (toEdn overlay)}
  '';

  closureRepoGenerator =
    { dependencies ? []
    , repos ? defaultMavenRepos
    , fixedVersions ? []
    , overlayRepository ? {}
    , repositoryFile
    , ... }:
    aetherDownloader
      (toString repositoryFile)
      repos

      (dependencyList
        (dependencies ++ fixedVersions))

      (expandRepo overlayRepository);

  dependencyList = dependencies:
    map (desc:
      if desc ? dwn.mvn then
        coordinateFor desc.dwn.mvn
      else if builtins.isList desc then
        desc
      else throw "Not a list ${toString desc}"
    ) dependencies;

  coordinateFor =
    { artifact, version
    , extension ? "jar"
    , classifier ? ""
    , group ? artifact
    , ...
    }: [ group artifact extension classifier version ];

}
