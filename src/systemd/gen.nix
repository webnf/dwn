{ pkgs, lib
, scope ? "user" }: systemdConfig:
let
  system =
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
    modules = [ {
      systemd.user = systemdConfig;
    } ];
  };
  systemdLib = import <nixos/modules/system/boot/systemd-lib.nix> {
    inherit (system) config;
    inherit pkgs lib;
  };
in
systemdLib.generateUnits scope system.config.systemd."${scope}".units [] []
