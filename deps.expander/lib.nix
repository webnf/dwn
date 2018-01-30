{ lib, runCommand, callPackage
, toEdn
, filterDirs
}:
rec {

  depsExpander = repo: deps: fixedVersions: providedVersions: overlayRepo: runCommand "deps.nix" {
    inherit repo;
    ednDeps = toEdn deps;
    ednFixedVersions = toEdn fixedVersions;
    ednProvidedVersions = toEdn providedVersions;
    ednOverlayRepo = toEdn (filterDirs overlayRepo);
    launcher = callPackage ./default.nix { devMode = false; };
  } ''
    #!/bin/sh
    ## set -xv
    exec $launcher $out "$repo" "$ednDeps" "$ednFixedVersions" "$ednProvidedVersions" "$ednOverlayRepo";
  '';

  expandDependencies = { name
                       , dependencies ? []
                       , overlayRepo ? {}
                       , fixedVersions ? []
                       , providedVersions ? []
                       , fixedDependencies ? null # bootstrap hack
                       , closureRepo ? throw "Please pre-generate the repository add attribute `closureRepo = ./repo.edn;` to project `${name}`"
                       , ... }:
    let expDep = depsExpander
           closureRepo dependencies fixedVersions providedVersions overlayRepo;
        result = map ({ coordinate, ... }@desc:
          if lib.hasAttrByPath coordinate overlayRepo
          then lib.getAttrFromPath coordinate overlayRepo
          else desc
        ) (import expDep);
    in
    if isNull fixedDependencies
    then result
    else fixedDependencies;

}
