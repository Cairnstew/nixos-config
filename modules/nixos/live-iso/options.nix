{ lib, ... }:
let
  inherit (lib) mkOption types;
  isoSettingsSubmodule = (import ./submodule.nix { inherit lib; }).isoSettingsSubmodule;
in
{
  options.my.live = {
    isos = mkOption {
      type = types.attrsOf isoSettingsSubmodule;
      default = { };
      description = "Named live NixOS ISO configurations. Each entry becomes packages.live-iso-<name>.";
      example = {
        diagnostics = {
          baseModule = "minimal";
          extraPackages = [ "htop" "iotop" "nvme-cli" ];
          extraContents = [
            { source = "/path/to/preseed.cfg"; target = "/root/preseed.cfg"; }
          ];
          sshKeys = [ "ssh-ed25519 AAA... user@host" ];
        };
      };
    };
  };
}
