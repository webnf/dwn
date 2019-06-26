(import <nixpkgs/nixos> {
  configuration = { pkgs, ... }: {
    boot.isContainer = true;
    boot.loader.grub.enable = false;
    networking.hostId = "cafebabe";
    system.stateVersion = "18.03";
    nix.package = pkgs.nixUnstable;
    environment.systemPackages = with pkgs; [
      coreutils utillinux zsh strace less
    ];
  };
}).system
