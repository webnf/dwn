self: super:
let
  inherit (self) lib runCommand leinReader toEdn;
  filterPaths = lib.filter lib.pathExists;
  filters = {
    clj.sourceDirectories = filterPaths;
    jvm.sourceDirectories = filterPaths;
    jvm.resourceDirectories = filterPaths;
  };
  updateAttrs = filters: attrs:
    with self.lib;
    foldl
      (a: name:
        let f = getAttr name filters;
        in if hasAttr name a then
          setAttr a name
            (if isFunction f
             then f (getAttr name a)
             else updateAttrs f (getAttr name a))
        else a)
      attrs (attrNames filters);
in
{
  fromLein = projectClj:
    self.build (updateAttrs filters (self.leinDescriptor projectClj));

  leinDescriptor = projectClj: import (runCommand "project-descriptor.nix" {
    inherit projectClj;
    reader = self.lein.reader.result;
    projectCljOrig = toString projectClj;
  } ''
    echo "Generating Leiningen Descriptor for $projectClj -> $out"
    LEIN_HOME="`pwd`" exec $reader/bin/lein2nix "$projectClj" "$(dirname $projectCljOrig)" pr-descriptor > $out
  '');

}
