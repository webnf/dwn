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
    , providedVersions
    , ... }:
    aetherDownloader
      (toString repositoryFile)
      repos

      (map coordinateFor
        (dependencies ++ fixedVersions ++ providedVersions))

      (self.mvn.mapRepo (group: artifact: extension: classifier: version: dsc: {
        inherit group artifact extension classifier version;
        dependencies = map self.coordinateFor dsc.dependencies;
        fixedVersions = map self.coordinateFor dsc.fixedVersions;
        providedVersions = map self.coordinateFor dsc.providedVersions;
      }) overlayRepository);

  coordinateFor =
    { artifact, version
    , extension ? "jar"
    , classifier ? ""
    , group ? artifact
    , ...
    }: [ group artifact extension classifier version ];

}
