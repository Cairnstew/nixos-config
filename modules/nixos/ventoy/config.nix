{ config, lib, pkgs, ... }:
let
  cfg = config.my.programs.ventoy;
  inherit (lib) mkIf;

  # All Ventoy variants (pname differs per GUI: ventoy / ventoy-qt5 / ventoy-gtk3).
  ventoyPackages = with pkgs; [ ventoy ventoy-full ventoy-full-qt ventoy-full-gtk ];
in
{
  config = mkIf cfg.enable {
    # Derive from the packages themselves so a nixpkgs version bump can't leave
    # the names stale (e.g. 1.1.12 → 1.1.17) and break the system build.
    nixpkgs.config.permittedInsecurePackages = map (p: p.name) ventoyPackages;

    environment.systemPackages =
      if cfg.package == null then
        ventoyPackages
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
