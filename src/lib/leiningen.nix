{ runCommand, callPackage, project, leinReader, toEdn, lib }:
let filterPaths = lib.filter lib.pathExists; in
rec {
  fromLein = projectClj: args: let descriptor = (readDescriptor projectClj);
                         in project ((lib.recursiveUpdate (lib.recursiveUpdate {
                           passthru.dwn = {
                             inherit descriptor projectClj;
                             projectCljOrig = toString projectClj;
                           };
                           devMode = true;
                         } descriptor) args) // {
                           cljSourceDirs = filterPaths descriptor.cljSourceDirs;
                           jvmSourceDirs = filterPaths descriptor.jvmSourceDirs;
                           resourceDirs = filterPaths descriptor.resourceDirs;
                         });
  readDescriptor = projectClj: import (runCommand "project-descriptor.nix" {
    inherit projectClj leinReader;
    projectCljOrig = toString projectClj;
  } ''
    echo "Generating Leiningen Descriptor for $projectClj -> $out"
    LEIN_HOME="`pwd`" exec $leinReader/bin/lein2nix "$projectClj" "$(dirname $projectCljOrig)" pr-deps > $out
  '');

}
