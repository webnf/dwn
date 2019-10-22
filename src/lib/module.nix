self: super:
let inherit (self) lib comp; in
{

  instantiateModule = moduleList: overrideConfig: module:
    (self.lib.evalModules {
      modules = moduleList ++ [{
        config._module.args.pkgs = self;
        config._module.args.overrideConfig = overrideConfig;
      } module];
    }).config.result;

  buildWith = moduleList: overrideFn: pkg:
    let
      overrideConfig = cfn:
        self.buildWith moduleList (comp cfn overrideFn) pkg;
    in
      (self.instantiateModule
        moduleList overrideConfig
        ({ config, pkgs, lib, ... }:
          let expr = if builtins.isAttrs pkg then pkg else import pkg;
              dwn = if builtins.isFunction expr
                    then expr {
                      inherit pkgs lib overrideConfig;
                      config = config.dwn;
                    }
                    else expr;
          in overrideFn {
            imports = dwn.plugins or [];
            inherit dwn;
          }))
      // {
        inherit overrideConfig;
      };

  build = self.buildWith [ ../clojure/module.nix ] lib.id;

}
