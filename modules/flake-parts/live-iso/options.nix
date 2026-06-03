{ config, lib, inputs, ... }:
let
  inherit (lib) mkOption types;

  isoSettingsSubmodule = types.submodule {
    options = {
      baseModule = mkOption {
        type = types.enum [ "minimal" "graphical" "graphical-kde" ];
        default = "minimal";
        description = "Base installer CD module preset.";
      };

      system = mkOption {
        type = types.str;
        default = "x86_64-linux";
        description = "System architecture for the ISO evaluation.";
      };

      extraModules = mkOption {
        type = types.listOf types.raw;
        default = [ ];
        description = "Extra NixOS modules to include in the ISO configuration.";
      };

      extraPackages = mkOption {
        type = types.listOf types.package;
        default = [ ];
        description = "Extra system packages to include in the live image.";
      };

      sshKeys = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "SSH public keys authorized for the root user.";
      };

      rootPassword = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Initial hashed root password. Null disables password auth.";
      };

      squashfsCompression = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "gzip -Xcompression-level 1";
        description = ''
          Squashfs compression algorithm and options.
          Null uses the nixpkgs default (xz).
          Faster options: lz4, gzip -Xcompression-level 1
        '';
      };

      kernelParams = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "Additional kernel boot parameters.";
      };

      enableSSH = mkOption {
        type = types.bool;
        default = true;
        description = "Enable SSH daemon with PermitRootLogin.";
      };

      enableFlakes = mkOption {
        type = types.bool;
        default = true;
        description = "Enable nix-command and flakes experimental features.";
      };

      includeChannel = mkOption {
        type = types.bool;
        default = false;
        description = "Provide an initial NixOS channel copy so users don't need nix-channel --update first.";
      };

      isoName = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "nixos-custom-25.05-x86_64.iso";
        description = "Custom ISO filename. Null uses the nixpkgs default.";
      };

      volumeID = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "NIXOS_CUSTOM";
        description = "ISO volume label (max 32 chars).";
      };

      extraContents = mkOption {
        type = types.listOf (types.submodule {
          options = {
            source = mkOption {
              type = types.path;
              description = "Source file or derivation to copy into the ISO.";
            };
            target = mkOption {
              type = types.str;
              example = "/etc/some-file";
              description = "Target path in the ISO root filesystem.";
            };
          };
        });
        default = [ ];
        description = "Extra files to place at specific paths in the ISO root. Each entry copies source → target.";
        example = [
          { source = ./my-script.sh; target = "/root/setup.sh"; }
          { source = "/etc/machine-id"; target = "/etc/machine-id"; }
        ];
      };

      tailscale = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = "Enable Tailscale with accept-routes on boot.";
        };
        authKeyFile = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = ''
            Path to tailscale auth key file at runtime.
            The file must be present at this path in the live ISO root.
            If set, the autoconnect service will use this key instead of requiring manual auth.
            Typical usage: set to match extraContents target path.
          '';
          example = "/var/lib/tailscale/authkey";
        };
      };

      ventoy = mkOption {
        type = types.bool;
        default = false;
        description = "Automatically deploy this ISO to Ventoy USB during ventoy-deploy.";
      };
    };
  };
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
