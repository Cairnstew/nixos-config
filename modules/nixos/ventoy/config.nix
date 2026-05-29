{ config, lib, pkgs, ... }:
let
  cfg = config.my.programs.ventoy;
  inherit (lib) mkIf;
in
{
  config = mkIf cfg.enable {
    nixpkgs.config.permittedInsecurePackages = [
      "ventoy-1.1.12"
      "ventoy-qt5-1.1.12"
      "ventoy-gtk3-1.1.12"
    ];

    environment.systemPackages =
      if cfg.package == null then
        with pkgs; [ ventoy ventoy-full ventoy-full-qt ventoy-full-gtk ]
      else if cfg.package == "ventoy" then
        with pkgs; [ ventoy ]
      else if cfg.package == "ventoy-full" then
        with pkgs; [ ventoy-full ]
      else if cfg.package == "ventoy-full-qt" then
        with pkgs; [ ventoy-full-qt ]
      else
        with pkgs; [ ventoy-full-gtk ];
  };
}
