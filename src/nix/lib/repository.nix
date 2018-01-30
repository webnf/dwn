{ lib, fetchurl }:

rec {

  unwrapCoord = f: coordinate:
    let
      group = lib.elemAt coordinate 0;
      name = lib.elemAt coordinate 1;
      extension = lib.elemAt coordinate 2;
      classifier = lib.elemAt coordinate 3;
      version = lib.elemAt coordinate 4;
    in
      f group name extension classifier version;

  getRepoCoord = default: repo: unwrapCoord (getRepo default repo);

  getRepo = default: repo: g: n: e: c: v: repo."${g}"."${n}"."${e}"."${c}"."${v}" or default;

  mvnResolve =
        mavenRepos:
        { resolved-coordinate ? coordinate
        , resolved-base-version ? null
        , coordinate
        , sha1 ? null
        , dirs ? null
        , jar ? null
        , ... }:
    let resF = group: name: extension: classifier: version:
             let
               baseVersion = if isNull resolved-base-version then version else resolved-base-version;
             in
               if "dirs" == extension then
                 if isNull dirs then throw "Dirs for ${toString coordinate} not found" else dirs
               else if "jar" == extension
                    && isNull sha1 then
                 if isNull jar then throw "Jar file for ${toString coordinate} not found" else [ jar ]
               else [ ((fetchurl {
                          name = "${name}-${version}.${extension}";
                          urls = mavenMirrors mavenRepos group name extension classifier baseVersion version;
                          inherit sha1;
                                # prevent nix-daemon from downloading maven artifacts from the nix cache
                 })  // { preferLocalBuild = true; }) ];
    in
      unwrapCoord resF coordinate;

  mavenMirrors = mavenRepos: group: name: extension: classifier: version: resolvedVersion: let
    dotToSlash = lib.replaceStrings [ "." ] [ "/" ];
    tag = if classifier == "" then "" else "-" + classifier;
    mvnPath = baseUri: "${baseUri}/${dotToSlash group}/${name}/${version}/${name}-${resolvedVersion}${tag}.${extension}";
  in # builtins.trace "DOWNLOADING '${group}' '${name}' '${extension}' '${classifier}' '${version}' '${resolvedVersion}'"
       (map mvnPath mavenRepos);

  filterDirs = overlayRepo:
    mapRepoVals (desc: builtins.removeAttrs desc [ "dirs" "overrideProject" ]) overlayRepo;

  mapRepoVals = f: repo:
    let mapVals = depth: vals:
      if depth > 0 then
        lib.mapAttrs (_: v: mapVals (depth - 1) v) vals
      else
        f vals;
    in
      mapVals 5 repo;

  descriptorPaths = desc:
    let pkg = lib.elemAt desc 2;
    in if pkg == "dirs"
      then lib.elemAt desc 5
      else if pkg == "jar"
      then [ (lib.elemAt desc 5) ]
      else throw "Unknown packaging '${pkg}'";

  mergeRepos = lib.recursiveUpdate;

}
