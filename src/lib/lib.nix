self: super:

with builtins;
with self.lib;
{
  lib = (super.lib or {}) // {
    tryOr = exp: def: msg:
      catch msg def (tryEval exp);
    catch = msg: def: { success, value }:
      if success
      then value
      else trace "Caught: ${msg}" def;
  };
}
