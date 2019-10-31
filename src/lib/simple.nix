self: super:

with self.lib;

{
  comp = g: f: x: g (f x);

  mapLens = pathFn: rec {
    has = o: p:
      hasAttrByPath (pathFn p) o;
    get = o: p:
      getAttrFromPath (pathFn p) o;
    getDefault = o: p: d:
      if has o p then get o p else d;
    set = o: p: v:
      recursiveUpdate o (setAttrByPath (pathFn p) v);
  };

  pinL = self.mapLens ({ group, artifact, ...}: [ group artifact ]);
  repoL = self.mapLens ({ group, artifact, extension, classifier, version, ... }:
    [ group artifact extension classifier version ]);

  subPath = path: drv: self.runCommand (drv.name + "-" + replaceStrings ["/"] ["_"] path) {
    inherit path;
  } ''
    mkdir -p $out/$(dirname $path)
    ln -s ${drv} $out/$path
  '';

  uniqifyingSymlinkJoin = name: classpath: self.runCommand name {
    inherit classpath;
  } ''
    mkdir -p $out/share/java
    cd $out/share/java
    for c in $classpath; do
      local targetOrig=$out/share/java/$(stripHash $c)
      local target=$targetOrig
      local cnt=0
      while [ -L $target ]; do
        target=$targetOrig-$cnt
        cnt=$(( cnt + 1 ))
      done
      ln -s $c $target
    done
  '';

  selectAttrs = names: a:
    listToAttrs
      (map (n: nameValuePair n a.${n})
        (filter (n: a ? ${n})
          names));

  reduceAttrs = f: s: a:
    foldl' (s: n: f s n (getAttr n a))
      s (attrNames a);

  mergeAttrsWith = mf: a1: a2:
    self.reduceAttrs
      (a: n: v:
        setAttr a n
          (if hasAttr n a
           then (mf n (getAttr n a) v)
           else v))
      a1 a2;

  internalDefault = v:
    mkOption {
      default = v;
      type = types.unspecified;
      internal = true;
    };

  errorDerivation = name: msg:
    self.runCommand name { inherit name msg; } ''
      echo BUILD ERROR: $name: $msg >&2
      exit 1
    '';

  ## Debugging tools

  cutAttrLayers = n: a:
    if n > 0 then
      mapAttrs (v: self.cutAttrLayers (n - 1) a) a
    else attrNames a;

}
