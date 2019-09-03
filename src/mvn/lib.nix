self: super:

with self.lib;
{
  mvnResult = {dependencies, fixedDependencies, overlayRepository, ... }: {
    overlayRepository = foldl self.mergeRepos overlayRepository
      (map
        ({ dwn, ... }:
          self.repoSingleton dwn.mvn)
        (filter (d: d ? dwn.mvn) (dependencies ++ fixedDependencies)));
    dependencies = map
      (d: if d ? dwn.mvn
          then self.coordinateFor d.dwn.mvn
          else d)
      dependencies;
    fixedDependencies = map
      (d: if d ? dwn.mvn
          then self.coordinateFor d.dwn.mvn
          else d)
      fixedDependencies;
  };
}
