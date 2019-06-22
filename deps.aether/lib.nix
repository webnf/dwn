{ lib, writeScript, callPackage
, toEdn
, defaultMavenRepos
, filterDirs
}:

rec {

  aetherDownloader = repoFile: repos: deps: overlay: writeScript "repo.edn.sh" ''
    #!/bin/sh
    launcher="${callPackage ./default.nix { devMode = false; }}"
    ednDeps=$(cat <<EDNDEPS
    ${toEdn deps}
    EDNDEPS
    )
    ednRepos=$(cat <<EDNREPOS
    ${toEdn repos}
    EDNREPOS
    )
    ednOverlay=$(cat <<EDNOVERLAY
    ${toEdn overlay}
    EDNOVERLAY
    )
    exec "$launcher" "${repoFile}" "$ednDeps" "$ednRepos" "$ednOverlay"
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
      (dependencies ++ fixedVersions)
      (filterDirs overlayRepo);

}
