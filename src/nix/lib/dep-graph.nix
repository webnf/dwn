{ lib }:

rec {

  callWithArt = art: f:
  let
    version = if 3 == lib.length art then lib.elemAt art 2 else "DEFAULT";
    name = lib.elemAt art 1;
    group = lib.elemAt art 0;
  in f group name version;

  get = m: k: lib.getAttr k m;

  getIn = m: ks:
    if lib.length ks == 0
    then m
    else getIn (get m (lib.head ks)) (lib.tail ks);

  assoc = m: k: v: m // { "${k}" = v; };
  assocIn = m: ks: v:
    let k = (lib.head ks); in
    if lib.length ks == 0
    then v
    else assoc m k (assocIn (get m k) (lib.tail ks) v);

  nth = lib.elemAt;

  artifactDependencies = { dependencies }: art:
    getIn dependencies art;

  prewalkReduce = getChildren: f: root: acc:
    lib.foldl (prewalkReduce getChildren) f (f acc root) (getChildren root);

  reduceDeps = cat: f: acc: root:
    prewalkReduce (artifactDependencies cat) f root acc;

  findUsedVersions = cat: root:
    reduceDeps cat (art: acc:
      (callWithArt art
        (g: n: v: assocIn acc [g n] v))
    ) {} root;

  expandDependencies = let
    isSeen = art: seen:  seen."${artString art}" or false;
    addSeen = art: seen: seen // { "${artString art}" = true; };
    artString = art: callWithArt art (g: n: v: "${g}:${n}:${v}");
    addDep = cat: arg@{res, seen}: art:
      if isSeen art seen then arg
      else let arg' = addDeps cat arg (artifactDependencies cat art);
            in { inherit (arg) seen;
                 res = [ art ] ++ arg'.res; };
    addDeps = cat: arg: deps:
      lib.foldl ({res, seen}: art: let
        subDeps = addDeps cat;
      in {
        res = if isSeen art seen then res
              else [ art ] ++ addDeps cat;
      }) arg (lib.reverseList deps);
  in cat: deps: seen:
    lib.foldl ({res, seen}: art: {
        res = if isSeen art seen
              then res else [ art ] ++ res;
        seen = addSeen art seen;
      })
      {res = [];
       inherit seen;}
      (lib.reverseList deps);
}
