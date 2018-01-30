{ lib, writeScript, callPackage
, toEdn
, defaultMavenRepos
, filterDirs
}:

rec {

  aetherDownloader = repos: deps: overlay: writeScript "repo.edn.sh" ''
    #!/bin/sh
    if [ -z "$1" ]; then
      echo "$0 <filename.out.edn>"
      exit 1
    fi
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
    exec "$launcher" "$1" "$ednDeps" "$ednRepos" "$ednOverlay"
  '';

  closureRepoGenerator = { dependencies ? []
                         , mavenRepos ? defaultMavenRepos
                         , fixedVersions ? []
                         , overlayRepo ? {}
                         , ... }:
    aetherDownloader
      mavenRepos
      (dependencies ++ fixedVersions)
      (filterDirs overlayRepo);

}
