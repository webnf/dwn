self: super:

with self.lib;
{
  dwn = recursiveUpdate super.dwn {
    mvn.result = {dependencies, overlayRepository, ... }: {
      overlayRepository = foldl self.mergeRepos overlayRepository
        (map
          ({ dwn, ... }:
            self.repoSingleton dwn.mvn)
          (filter (d: d ? dwn.mvn) dependencies));
      dependencies = map
        (d: if d ? dwn.mvn
            then self.coordinateFor d.dwn.mvn
            else d)
        dependencies;
    };
  };
}
