self: super:

let
  inherit (self) lib runCommand toEdn expandRepo depsExpander;
  inherit (self.deps) expander;
in {

  depsExpander = name: repo: dependencies: fixedVersions: providedVersions: overlayRepo: runCommand "${name}-deps.nix" {
    inherit repo;
    ednDeps = toEdn dependencies;
    ednFixedVersions = toEdn fixedVersions;
    ednProvidedVersions = toEdn providedVersions;
    ednOverlayRepo = toEdn (expandRepo overlayRepo);
    launcher = expander.dwn.binaries.expand;
  } ''
    #!/bin/sh
    exec $launcher $out "$repo" "$ednDeps" "$ednFixedVersions" "$ednProvidedVersions" "$ednOverlayRepo";
  '';

  expandDependencies =
    { name
    , dependencies ? []
    , overlayRepository ? {}
    , fixedVersions ? []
    , providedVersions ? []
    , closureRepo ? throw "Please pre-generate the repository add attribute `closureRepo = ./repo.edn;` to project `${name}`"
    , ... }:
    let
      deps = depsExpander name closureRepo dependencies fixedVersions providedVersions overlayRepository;
    in
      map ({ coordinate, ... }@desc:
        if lib.hasAttrByPath coordinate overlayRepository
        then lib.getAttrFromPath coordinate overlayRepository
        else desc
      ) (import deps); #(map (x: builtins.trace x.coordinate x) (import deps));
}
