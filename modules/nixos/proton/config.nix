{ config, lib, pkgs, ... }:
let
  cfg = config.my.programs.proton;
in
{
  config = lib.mkIf cfg.enable {
    programs.steam.extraCompatPackages =
      lib.optional cfg.ge.enable pkgs.proton-ge-bin
      ++ cfg.extraCompatPackages;

    environment.systemPackages =
      lib.optionals cfg.protonup-qt.enable [ pkgs.protonup-qt ];
  };
}
