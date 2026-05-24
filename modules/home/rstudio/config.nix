{ config, lib, pkgs, ... }:

let
  cfg = config.my.programs.rstudio;

  rstudio-with-packages =
    cfg.package.override {
      packages = cfg.rPackages;
    };
in
{
  config = lib.mkIf cfg.enable {
    home.packages = [
      rstudio-with-packages
      pkgs.nerd-fonts.jetbrains-mono
      pkgs.nerd-fonts.fira-code
      pkgs.noto-fonts
      pkgs.liberation_ttf
      pkgs.texlive.combined.scheme-full
      pkgs.chromium
    ] ++ cfg.extraPackages;
  };
}
