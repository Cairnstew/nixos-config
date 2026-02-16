{ lib, config, pkgs, ... }:

let
  cfg = config.my.programs.ventoy;
in
{
  options.my.programs.ventoy = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable Ventoy and allow required insecure packages";
    };
  };

  config = lib.mkIf cfg.enable {
    nixpkgs.config.permittedInsecurePackages = [
      "ventoy-1.1.05"
      "ventoy-qt5-1.1.05"
      "ventoy-gtk3-1.1.05"
    ];

    environment.systemPackages = with pkgs; [
      ventoy
      ventoy-full
      ventoy-full-qt
      ventoy-full-gtk
    ];
  };
}
