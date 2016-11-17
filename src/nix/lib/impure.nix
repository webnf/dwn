{ callPackage, cljNsLauncher, toEdn }:

let mkRepository = { repos, timestamp, root
                   , runCommand }:
  runCommand "repo-builder-${timestamp}" {
    inherit launcher;
  } ''
    exec $launcher $out '${toEdn root}'
  '';
    launcher = cljNsLauncher {
      name = "repo-builder-clj";
      namespace = "webnf.dwn.tasks.repo-descriptor";
    };

{
  fetchRepo = repos: timestamp: group: artefact: version:
    import (callPackage mkRepository {
      inherit repos timestamp;
      root = [ group artefact version ];
    });
}
