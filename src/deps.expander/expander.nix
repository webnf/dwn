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
      recursiveUpdate o (setAttrByPath (pathFn p) v);
  };
  
  pinL = mapLens ({ group, artifact, ...}: [ group artifact ]);
  repoL = mapLens ({ group, artifact, extension, classifier, version, ... }:
    [ group artifact extension classifier version ]);

  filterExclusions' = exclusions: filter (x:
    isNull
      (findFirst (e: x.group == e.group && x.artifact == e.artifact)
        null exclusions)
  );

  filterExclusions = ex: l:
    trace "${toJSON ex} ${toJSON l}"
      (traceVal (filterExclusions' ex l));
  
  pinpointDeps = repository: providedVersions: treeExclusions: treeFixedVersions: coordinates: result:
    foldl
      (result: { group, artifact, extension, classifier, version, exclusions, fixedVersions, scope, dependencies }@coord:
        let
          have = pinL.has result coord;
          haveR = pinL.get result coord;
          newer = ! have || versionOlder haveR.version version;
          fixPin =
            pinL.getDefault treeFixedVersions coord
              {
                inherit extension classifier;
                dependencies = map self.coordinateInfo dependencies;
                exclusions = if have then intersectLists haveR.exclusions exclusions else exclusions;
                version = if newer then version else haveR.version;
              };
        in
          if have && version == fixPin.version && exclusions == fixPin.exclusions then
            result
          else
            let treeExclusions' = unique ( treeExclusions ++ fixPin.exclusions ); in
            pinpointDeps repository providedVersions treeExclusions' treeFixedVersions
              (let entry = repoL.get repository (coord // fixPin);
               in
                 filterExclusions treeExclusions' fixPin.dependencies)
              (pinL.set result coord fixPin))
      result coordinates;

  expandDeps = repository: treeExclusions: versionPins: coordinates: result:
    foldl
      ({ expanded, seen }@result: { group, artifact, ... }@coord:
        let
          pin = pinL.get versionPins coord;
          treeExclusions' = unique ( treeExclusions ++ pin.exclusions );
        in
          if isNull pin.version then
            warn "Unversioned dependency ${group} ${artifact} not it repository; discarding"
              result
          else if findFirst (x: x == [ group artifact ]) false seen then
            result
          else
            trace "${group} ${artifact} -> ${toJSON pin.dependencies}"
            (expandDeps repository treeExclusions' versionPins
              (filterExclusions treeExclusions' pin.dependencies)
              {
                expanded = [ (pin // {
                  inherit group artifact;
                }) ] ++ expanded;
                seen = [[ group artifact ]] ++ seen;
              }))
      result (reverseList coordinates);

  fromRepo = repositoryFile: overlayRepository:
    self.mergeByType self.repoT [ (importJSON repositoryFile) overlayRepository ];
  fromFixedVersions = fixedVersions:
    foldl (fv: v:
      let i = self.coordinateInfo v;
      in pinL.set fv i {
        inherit (i) version extension classifier dependencies exclusions;
      }
    ) {} fixedVersions;
  fromProvidedVersions = providedVersions:
    unique (
      map (v: let x = self.coordinateInfo v;
              in [ x.group x.artifact ])
        providedVersions);
    
in

{      

  inherit pinL repoL;
  
  depsExpander3 = repo: dependencies: fixedVersions: providedVersions:
    let tfv = fromFixedVersions fixedVersions;
        pv = fromProvidedVersions providedVersions;
        pins = pinpointDeps repo pv [] tfv dps {};
        dps = map self.coordinateInfo dependencies;
    in
      trace "PINS: ${toJSON pins}"
      (expandDeps repo [] pins dps {
        expanded = [];
        seen = pv;
      }).expanded;
        
    
  expandDependencies3 = cfg:
    let
      name = cfg.dwn.name;
      inherit (cfg.dwn.mvn) providedVersions repositoryFile;
      #  dependencies fixedVersions overlayRepository;
      inherit (cfg.passthru.dwn.mvn) dependencies fixedVersions overlayRepository;
      repo = fromRepo repositoryFile overlayRepository;
      deps = self.depsExpander3 repo dependencies fixedVersions [];
    in
      # deps;
      # trace (toJSON repo)
      map (v: (repoL.get repo v) // v) deps;

  # TODO instantiate
      # map ({ coordinate, ...}@desc:
      #   if hasAttrByPath coordinate overlayRepository
      #   then ((getAttrFromPath coordinate overlayRepository).instantiate
      #     {
      #       inherit overlayRepository repositoryFile fixedVersions;
      #     }).dwn.mvn
      #   else self.unpackEdnDep desc) deps;

}
