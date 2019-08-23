{ config, lib, pkgs, ... }:

with lib;

let
  subPath = path: drv: pkgs.runCommand (drv.name + "-" + lib.replaceStrings ["/"] ["_"] path) {
    inherit path;
  } ''
    mkdir -p $out/$(dirname $path)
    ln -s ${drv} $out/$path
  '';
  systemd =
    import <nixos/lib/eval-config.nix> {
      system = builtins.currentSystem;
      baseModules = [
        <nixos/modules/misc/assertions.nix>
        <nixos/modules/misc/nixpkgs.nix>
        <nixos/modules/system/boot/systemd.nix>
        <nixos/modules/config/shells-environment.nix>
        <nixos/modules/config/system-environment.nix>
        <nixos/modules/config/system-path.nix>
        <nixos/modules/security/pam.nix>
      ];
      modules = [{
        systemd.user = config.dwn.systemd;
      }];
    };
  systemdLib = import <nixos/modules/system/boot/systemd-lib.nix> {
    inherit (systemd) config;
    inherit pkgs lib;
  };
  genUnits = scope:
    systemdLib.generateUnits scope systemd.config.systemd."${scope}".units [] [];
in
{
  imports = [
    ./base-module.nix
  ];

  options.dwn.systemd = mkOption {
    type = types.unspecified;
  };

  config.dwn.paths = [(subPath "share/systemd" (genUnits "user"))];
}
