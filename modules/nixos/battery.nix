{flake, lib, config, pkgs, ... }:
let
  inherit (flake) config inputs;
  inherit (flake.inputs) self;
in

{
  services.tlp.enable = false;
  services.power-profiles-daemon.enable = false;
  services.thermald.enable = true;

  services.auto-cpufreq = {
    enable = true;
    settings = {
      battery = {
        governor = "powersave";
        turbo = "never";
      };
      charger = {
        governor = "performance";
        turbo = "auto";
      };
    };
  };
}
