self: super:

with self.lib; with types;
{

  mergeByType = T: vals:
    T.merge []
      (map (v:
        { file = "m"; value = v; }
      ) vals);

  mergeByType2 = T: a: b:
    self.mergeByType T [a b];

  urlT = either path str;
  pathT = either path package;
  pathsT = listOf self.pathT;

  # Value of type `inputT` converted to `outputT` using `mapFn` before merging with `outputT`.
  typeFmap = inputT: mapFn: outputT:
    assert assertMsg (inputT.getSubModules == null)
      "typeFmap: inputT must not have submodules (it’s a ${
        inputT.description})";
    mkOptionType rec {
      name = "typeFmap";
      description = "${inputT.description} fmapped to ${outputT.description}";
      check = x: inputT.check x && outputT.check (mapFn x);
      merge = loc: defs:
        outputT.merge loc (map (def: def // { value = mapFn def.value; }) defs);
      getSubOptions = outputT.getSubOptions;
      getSubModules = outputT.getSubModules;
      substSubModules = m: typeFmap inputT mapFn (outputT.substSubModules m);
      typeMerge = t1: t2: null;
      functor = (defaultFunctor name) // { wrapped = outputT; };
    };

  # Value of type `inputT` converted to `outputT` using `mapFn` after merging with `inputT`.
  typeMap = inputT: mapFn: outputT:
    assert assertMsg (outputT.getSubModules == null)
      "typeMap: outputT must not have submodules (it’s a ${
        outputT.description})";
    mkOptionType rec {
      name = "typeMap";
      description = "${inputT.description} mapped to ${outputT.description}";
      check = x: inputT.check x && outputT.check (mapFn x);
      merge = loc: defs:
        mapFn (inputT.merge loc defs);
      getSubOptions = inputT.getSubOptions;
      getSubModules = inputT.getSubModules;
      substSubModules = m: typeMap (inputT.substSubModules m) mapFn outputT;
      typeMerge = t1: t2: null;
      functor = (defaultFunctor name) // { wrapped = outputT; };
    };

}
