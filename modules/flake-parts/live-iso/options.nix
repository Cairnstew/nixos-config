{ config, lib, inputs, ... }:
let
  inherit (lib) mkOption types;
  isoSettingsSubmodule = (import ../../nixos/live-iso/submodule.nix { inherit lib; }).isoSettingsSubmodule;
in
{
  options.live = {
    isos = mkOption {
      type = types.attrsOf isoSettingsSubmodule;
      default = { };
      description = "Named live NixOS ISO configurations. Each entry becomes packages.live-iso-<name>.";
      example = {
        diagnostics = {
          baseModule = "minimal";
          extraPackages = [ "htop" "iotop" "iperf" "nvme-cli" ];
          extraContents = [
            { source = "/path/to/preseed.cfg"; target = "/root/preseed.cfg"; }
          ];
          sshKeys = [ "ssh-ed25519 AAA... user@host" ];
          enableSSH = true;
        };
        rescue = {
          baseModule = "graphical";
          extraModules = [ "path/to/extra-config.nix" ];
          system = "x86_64-linux";
        };
      };
    };
  };
}
