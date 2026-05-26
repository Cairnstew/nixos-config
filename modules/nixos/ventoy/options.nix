{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.my.programs.ventoy = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Enable Ventoy support — installs CLI tools and the deploy script.";
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
}
