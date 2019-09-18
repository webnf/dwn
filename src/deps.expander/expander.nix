self: super:
with builtins;
with self.lib;

let
  mapLens = pathFn: rec {
    has = o: p:
      hasAttrByPath (pathFn p) o;
    get = o: p:
      getAttrFromPath (pathFn p) o;
    getDefault = o: p: d:
      if has o p then get o p else d;
    set = o: p: v:
      setAttrByPath (pathFn p) o;
  };
  
  pinL = mapLens ({ group, artifact, ...}: [ group artifact ]);

  filterExclusions = exclusions: filter (x:
    isNull
      (findFirst (e: x.group == e.group && x.artifact == e.artifact)
        null exclusions)
  );
  
  pinpointDeps = repository: providedVersions: treeExclusions: treeFixedVersions: coordinates: result:
    foldl
      (result: { group, artifact, extension, classifier, version, exclusions, fixedVersions, scope }@coord:
        let
          have = pinL.has result coord;
          haveR = pinL.get result coord;
          newer = ! have || versionOlder haveR.version version;
          fixPin =
            pinL.getDefault treeFixedVersions coord
              {
                inherit extension classifier dependencies;
                exclusions = if have then intersectLists haveR.exclusions exclusions else exclusions;
                version = if newer then version else haveR.version;
              };
        in
        if version == fixPin.version && exclusions == fixPin.exclusions then
          result
        else
          let treeExclusions* = unique ( treeExclusions ++ fixPin.exclusions ); in
          pinpointDeps repository providedVersions treeExclusions* treeFixedVersions
            (let entry = repoL.get repository (coord // fixPin);
             in
               filterExclusions treeExclusions* dependencies)
            (pinL.set result coord fixPin))
      result coordinates;

  expandDeps = repository: treeExclusions: versionPins: coordinates: result:
    foldl
      ({ expanded, seen }@result: { group, artifact, ... }@coord:
        let
          pin = pinL.get versionPins coord;
          treeExclusions* = unique ( treeExclusions ++ pin.exclusions );
        in
          if isNull pin.version then
            warn "Unversioned dependency ${group} ${artifact} not it repository; discarding"
              result
          else if findFirst (x: x == [ group artifact ]) false seen then
            result
          else
            expandDeps repository treeExclusions* versionPins
              (filterExclusions treeExclusions* pin.dependencies)
              {
                expanded = [ pin ] ++ expanded;
                seen = [[ group artifact ]] ++ seen;
              })
      result (reverseList coordinates);

  readRepo = repositoryFile: overlayRepository:
    self.mergeByType self.repoT [ (importJSON repositoryFile) overlayRepository ];
  readFixedVersions = fixedVersions:
    foldl (fv
in

{      
  
  depsExpander3 = repositoryFile: dependencies: fixedVersions: providedVersions: overlayRepository:
    let repo = readRepo repositoryFile overlayRepository;
        tfv = readFixedVersions fixedVersions;
        pv = readProvidedVersions providedVersions;
        pins = pinpointDeps repo pv [] tfv dependencies {};
    in
      (expandDeps repo [] pins dependencies {
        expanded = [];
        seen = [];
      }).expanded;
        
    
  expandDependencies3 = cfg:
    let
      name = cfg.dwn.name;
      inherit (cfg.dwn.mvn) providedVersions repositoryFile;
      inherit (cfg.passthru.dwn.mvn) dependencies fixedVersions overlayRepository;
      deps =
        self.depsExpander3 repositoryFile dependencies fixedVersions []
          (self.trimRepository overlayRepository);
    in
      map ({ coordinate, ...}@desc:
        if hasAttrByPath coordinate overlayRepository
        then ((getAttrFromPath coordinate overlayRepository).instantiate
          {
            inherit overlayRepository repositoryFile fixedVersions;
          }).dwn.mvn
        else self.unpackEdnDep desc) deps;
}
