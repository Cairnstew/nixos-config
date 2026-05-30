{ lib, ... }:
let
  inherit (lib) mkOption types;

  isoSubmodule = types.submodule {
    options = {
      source = mkOption {
        type = types.package;
        description = "ISO derivation or store path.";
      };
      target = mkOption {
        type = types.str;
        description = "Target path on the Ventoy USB (e.g., /iso/windows/win11.iso).";
        example = "/iso/windows/22631.7079.23H2.PRO.X64.EN.iso";
      };
    };
  };
in
{
  options.my.programs.ventoy = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Enable Ventoy support — installs CLI tools (ventoy2disk.sh, etc.). Use `nix run .#ventoy-deploy` to deploy.";
    };

    package = mkOption {
      type = types.nullOr (types.enum [
        "ventoy"
        "ventoy-full"
        "ventoy-full-qt"
        "ventoy-full-gtk"
      ]);
      default = null;
      description = ''
        Which Ventoy package variant to install.
        - null: Install all variants (current default behavior)
        - "ventoy": CLI-only (ventoy2disk.sh)
        - "ventoy-full": CLI + Web UI
        - "ventoy-full-qt": CLI + Qt GUI
        - "ventoy-full-gtk": CLI + GTK GUI
      '';
      example = "ventoy-full";
    };
  };

  options.my.ventoy = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "This host contributes ISOs and config to the Ventoy multi-boot USB.";
    };

    isos = mkOption {
      type = types.attrsOf isoSubmodule;
      default = { };
      description = "ISOs this host contributes to the Ventoy USB deployment.";
      example = {
        win11-23h2 = {
          source = "/nix/store/...-windows.iso";
          target = "/iso/windows/win11.iso";
        };
      };
    };

    hostIso = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Deprecated: Use `ventoy.installerIso.enable` in the flake-parts config instead.
          This per-host ISO builder (extendModules) has been replaced by a standalone
          nixpkgs.nixosSystem evaluation — faster, no recursion issues, no tty errors.
        '';
      };
    };
  };
}
