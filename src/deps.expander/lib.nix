{ lib, runCommand, callPackage
, toEdn, subProjectOverlay
, filterDirs, mergeRepos
, deps
}:
rec {

  depsExpander = repo: dependencies: fixedVersions: providedVersions: overlayRepo: runCommand "deps.nix" {
    inherit repo;
    ednDeps = toEdn dependencies;
    ednFixedVersions = toEdn fixedVersions;
    ednProvidedVersions = toEdn providedVersions;
    ednOverlayRepo = toEdn (filterDirs overlayRepo);
    launcher = deps.expander.dwn.binaries.expand;
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
    let dependencies' = map (d:
          # builtins.trace (if builtins.isAttrs d then builtins.attrNames d.dwn.mvn else d)
          (if builtins.isList d then d
           else with d.dwn.mvn; [group artifact extension classifier version])
        ) dependencies;
        overlayRepo' = mergeRepos overlayRepo (subProjectOverlay {
          subProjects = lib.filter (d: ! builtins.isList d) dependencies;
          inherit overlayRepo closureRepo fixedVersions;
        });
        expDep = depsExpander
           closureRepo dependencies' fixedVersions providedVersions overlayRepo';
        result = map ({ coordinate, ... }@desc:
          if lib.hasAttrByPath coordinate overlayRepo'
          then lib.getAttrFromPath coordinate overlayRepo'
          else desc
        ) (import expDep);
    in
    if isNull fixedDependencies
    then result
    else fixedDependencies;

}
