{ lib, mergeRepos, callPackage, toEdnPP, writeText, shellBinder, keyword-map }:
pluginProject:

pluginProject.overrideProject
  ({ overlayRepo ? {}, dependencies ? [], mainNs ? {}
   , nrepl ? {}, subProjects ? []
   , ... }: let
     config = {
       host = nrepl.config.host or "127.0.0.1";
       port = nrepl.config.port or 4050;
       middleware = nrepl.config.middleware or [];
       enable-cider = nrepl.config.enable-cider or true;
     };
   in {
     # overlayRepo =  mergeRepos overlayRepo {
     #   "webnf.dwn"."nrepl"."dirs".""."BUILTIN" = {
     #     coordinate = [ "webnf.dwn" "nrepl" "dirs" "" "BUILTIN" ];
     #     dirs = [ "${callPackage ./nrepl-project.nix { devMode = false; }}/lib" ];
     #   };
     # };
     dependencies = dependencies ++ [
       [ "webnf.dwn" "nrepl" "0.0.1" ]
     ];
     ## FIXME replace this with a project-dependency mechanism,
     ##       that can re-use sub-project-repos
     subProjects = subProjects ++ [
       (callPackage ./nrepl-project.nix { devMode = false; })
     ];
     mainNs = mainNs // {
       dwn-nrepl = {
         namespace = "webnf.dwn.nrepl";
         prefixArgs = [ ( toEdnPP ( keyword-map config)) ];
       };
     };
     passthru.dwn.nrepl.config = config;
     # FIXME: create a facility for this
   }
  )
