{ lib
, defaultMavenRepos
, symbol
, mvnResolve
, keyword
, keyword-map
, dwn
, artifactClasspath
, expandDependencies
}:

rec {

  mkConfig = optionsDecl: options: options; ## FIXME validate, fill defaults

  projectDescriptor = args@{
                        name
                      , group ? name
                      , version ? "0-SNAPSHOT"
                      , mainNs ? {}
                      , components ? {}
                      , mavenRepos ? defaultMavenRepos
                      , providedVersions ? []
                      , ... }:
                      binder@{
                        parentLoader ? keyword "webnf.dwn" "app-loader"
                      , ...}:
  let containerName = keyword name "container"; in
  keyword-map ({
      "${name}/container" = dwn.container {
        loaded-artifacts = map (artifactDescriptor mavenRepos) ([{
          coordinate = [ group name "dirs" "" version];
          dirs = artifactClasspath args;
        }] ++ expandDependencies args);
        parent-loader = parentLoader;
        provided-versions = providedVersions;
      };
    } // lib.listToAttrs (projectNsLaunchers name containerName mainNs binder
                       ++ projectComponents name containerName components binder));

  projectNsLaunchers = prjName: container: mainNs: { mainArgs ? {}, ... }:
  lib.mapAttrsToList (
      name: ns: {
        name = "${prjName}/${name}";
        value = dwn.ns-launcher {
          inherit container;
          main = symbol null ns;
          args = mainArgs.${name} or [];
        };
      }
  ) mainNs;

  projectComponents = prjName: container: components: { componentConfig ? {}, ... }:
  lib.mapAttrsToList (
      name: { factory, options ? {} }: {
        name = "${prjName}/${name}";
        value = dwn.component {
          inherit factory container;
          config = mkConfig options componentConfig.${name} or {};
        };
      }
  ) components;

  artifactDescriptor = mavenRepos: args@{ coordinate
                                        , dirs ? null
                                        , ...}:
    coordinate ++ (if "dirs" == lib.elemAt coordinate 2
      then [dirs]
      else mvnResolve mavenRepos args
    );

}
