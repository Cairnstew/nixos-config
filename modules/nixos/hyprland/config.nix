{ config, lib, pkgs, flake, ... }:
let
  inherit (lib) mkIf;
  cfg = config.my.desktop.hyprland;
  inherit (flake) inputs;
  hyprlandPkgs = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system};
in
{
  imports = [
    { home-manager.sharedModules = [ ./home ]; }
  ];

  config = mkIf cfg.enable {
    programs.hyprland = {
      enable = true;
      package = hyprlandPkgs.hyprland;
      portalPackage = hyprlandPkgs.xdg-desktop-portal-hyprland;
    };

    security.pam.services.hyprlock = { };

    environment.sessionVariables.NIXOS_OZONE_WL = "1";

    environment.systemPackages = with pkgs; [
      grimblast
      acpi
      acpilight
      pavucontrol
      hyprshade
      hyprshot
      hyprpaper
      playerctl
      hyprlock
      wl-clipboard
    ];
  };
}
