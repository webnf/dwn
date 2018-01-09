{ runCommand, callPackage, project, leinReader, toEdn }:

rec {
  fromLein = projectClj: let descriptor = (readDescriptor projectClj);
                         in project ({
                           passthru.dwn = {
                             inherit descriptor projectClj;
                             projectCljOrig = toString projectClj;
                           };
                           devMode = true;
                         } // descriptor);
  readDescriptor = projectClj: import (runCommand "project-descriptor.nix" {
    inherit projectClj leinReader;
    projectCljOrig = toString projectClj;
  } ''
    echo "Generating Leiningen Descriptor for $projectClj -> $out"
    LEIN_HOME="`pwd`" exec $leinReader/bin/lein2nix "$projectClj" "$(dirname $projectCljOrig)" pr-deps > $out
  '');

}
