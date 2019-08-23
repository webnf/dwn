{ lib }:
let
  escapeQuotes = s: lib.replaceStrings ["\"" "\\"] ["\\\"" "\\\\"] (toString s);

  increaseIndent = p@{ levels ? [], ... }: level:
    p // { levels = levels ++ [ level ]; };

  newline = p@{ levels ? [], pretty, ... }:
    if pretty
    then "\n" + lib.concatStrings levels
    else " ";

in rec {

  syntax = rec {
    collection = attrs: opener: closer: children: {
      inherit children;
      collection = true;
      __toEdn = p: let
          pC = increaseIndent p " ";
        in  opener
          + lib.concatStringsSep
              (newline pC)
              (map (c: _toEdn pC c) children)
          + closer;
      __eq = v1: v2:
        if v1.type == v2.type && builtins.length v1.children == builtins.length v2.children
        then lib.foldl (res: i: res && data.eq (lib.elemAt (v1.children) i)
                                               (lib.elemAt (v2.children) i))
                       true lib.range 0 ((builtins.length v1.children) - 1)
        else false;
     __nth = c: i:
       lib.elemAt c.children i;
       
    } // attrs;
    atom = attrs: __toEdn: {
      collection = false;
      inherit __toEdn;
      __eq = v1: v2: if v1.type == v2.type then v1.val == v2.val else false;
    } // attrs;
    hash-map = kFn: vFn: children: collection {
      type = "map";
      __get = m: k:
        let found = lib.findFirst (e: data.eq k (kFn e))
                                  null
                                  children;
        in if isNull found then null else vFn found;
    } "{" "}"
     (map (c: {
        type = "map$pair";
        collection = true;
        children = [ (kFn c) (vFn c) ];
        __toEdn = p: "${_toEdn p (kFn c)} ${_toEdn p (vFn c)}";
      }) children);
    keyword = namespace: name: atom { type = "kw"; val = [ namespace name ]; } (p:
      ":${_toEdn p (symbol namespace name)}");
    symbol = namespace: name: atom {
        type = "sym"; val = [ namespace name ];
        __nix_str = s: s.__toEdn null;
      } (_:
        "${if isNull namespace
            then ""
            else namespace + "/"
         }${name}");
    keyword-map = attrs: hash-map
      (c: let ks = lib.splitString "/" c.key;
          in if lib.length ks > 1 then
               keyword (builtins.head ks) (lib.concatStringsSep "/" (builtins.tail ks))
             else
               keyword null c.key)
      (c: c.val)
      (lib.mapAttrsToList (key: val: {
         inherit key val;
       }) attrs);
    string-map = attrs: hash-map
      (c: syntax.string c.key)
      (c: c.val)
      (lib.mapAttrsToList (key: val: {
        inherit key val;
      }) attrs);
    vector = collection { type = "vector"; } "[" "]";
    set = collection { type = "set"; } "#{" "}";
    list = collection { type = "list"; } "(" ")";
    string = s: atom {
        type = "str"; val = s;
        __nix_str = s: toString s.val;
      } (_: "\"${escapeQuotes s}\"");
    bool = b: atom { type = "bool"; val = b; } (_: if b then "true" else "false");
    int = i: atom { type = "int"; val = i; } (_: toString i);
    nil = atom { type = "nil"; val = null; } (_: "nil");
    tagged = tag: val: collection { type = "tagged"; } "#" "" [tag val];
  };

  data = rec {

    get = m: k:
      (asEdn m).__get (asEdn m) (asEdn k);
    get-in = m: ks:
      if 0 == lib.length ks then m
      else if 1 == lib.length ks then get m (lib.elemAt ks 0)
      else get-in (get m (lib.elemAt ks 0)) (builtins.tail ks);
    eq = v1: v2: (asEdn v1).__eq (asEdn v1) (asEdn v2);
    nth = v: i: (asEdn v).__nth (asEdn v) (asEdn i);
    nix-str = s: (asEdn s).__nix_str (asEdn s);
    extract = tag: tagged:
      if eq (builtins.head tagged.children) tag then
        asEdn (lib.elemAt tagged.children 1)
      else
        throw "Not a #${toEdn tag}: ${toEdn tagged}";

    nix-list = lst: (asEdn lst).children;

  };
  
  asEdn = val:
    if isNull val
      then syntax.nil
    else if lib.isAttrs val && lib.hasAttr "__toEdn" val
      then val
    else if ! lib.isDerivation val && lib.isAttrs val
      then syntax.string-map (lib.mapAttrs (_: asEdn) val)
    else if lib.isList val
      then syntax.vector (map asEdn val)
    else if lib.isInt val
      then syntax.int val
    else if lib.isBool val
      then syntax.bool val
    else   syntax.string val;

  _toEdn = p: val: (asEdn val).__toEdn p;
  toEdn = _toEdn { pretty = false; };
  toEdnPP = _toEdn { pretty = true; };
}
