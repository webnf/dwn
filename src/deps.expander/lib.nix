self: super:

with self.lib;
let
  inherit (self) lib runCommand toEdn toEdnPP expandRepo depsExpander;
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

  depsExpander2 = name: repo: dependencies: fixedVersions: providedVersions: overlayRepo: runCommand "${name}-deps.nix" {
    inherit repo;
    ednDeps = toEdnPP dependencies;
    ednFixedVersions = toEdnPP fixedVersions;
    ednProvidedVersions = toEdnPP providedVersions;
    ednOverlayRepo = toEdnPP overlayRepo;
    launcher = expander.dwn.binaries.expand;
  } ''
    #!/bin/sh
    exec $launcher $out "$repo" "$ednDeps" "$ednFixedVersions" "$ednProvidedVersions" "$ednOverlayRepo";
  '';

  trimRepository = repo:
    self.mapRepoVals (desc: {
      inherit (desc) dependencies fixed-versions;
    }) repo;

  expandDependencies2 = cfg:
    let
      name = cfg.dwn.name;
      inherit (cfg.dwn.mvn) providedVersions repositoryFile;
      inherit (cfg.passthru.dwn.mvn) dependencies fixedVersions overlayRepository;
      deps =
        self.depsExpander2 name repositoryFile dependencies fixedVersions []
          (self.trimRepository overlayRepository);
    in
      map ({ coordinate, ...}@desc:
        if hasAttrByPath coordinate overlayRepository
        then ((getAttrFromPath coordinate overlayRepository).instantiate
          {
            inherit overlayRepository repositoryFile fixedVersions;
          }).dwn.mvn
        else self.unpackEdnDep desc) (import deps);
}
