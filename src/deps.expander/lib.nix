{ lib, runCommand, callPackage
, toEdn, subProjectOverlay
, filterDirs, mergeRepos
, deps, dependencyList, expandRepo
}:
rec {

  depsExpander = repo: dependencies: fixedVersions: providedVersions: overlayRepo: runCommand "deps.nix" {
    inherit repo;
    ednDeps = toEdn dependencies;
    ednFixedVersions = toEdn fixedVersions;
    ednProvidedVersions = toEdn providedVersions;
    ednOverlayRepo = toEdn (expandRepo overlayRepo);
    launcher = deps.expander.dwn.binaries.expand;
  } ''
    #!/bin/sh
    ## set -xv
    exec $launcher $out "$repo" "$ednDeps" "$ednFixedVersions" "$ednProvidedVersions" "$ednOverlayRepo";
  '';

  expandDependencies =
    { name
    , dependencies ? []
    , overlayRepository ? {}
    , fixedDependencies ? []
    , providedVersions ? []
    , closureRepo ? throw "Please pre-generate the repository add attribute `closureRepo = ./repo.edn;` to project `${name}`"
    , ... }:
    let
      deps = depsExpander closureRepo dependencies fixedDependencies providedVersions overlayRepository;
    in
      map ({ coordinate, ... }@desc:
        if lib.hasAttrByPath coordinate overlayRepository
        then lib.getAttrFromPath coordinate overlayRepository
        else desc
      ) (import deps);
}
