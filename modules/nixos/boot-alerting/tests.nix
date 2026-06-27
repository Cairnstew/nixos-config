{ config, lib, pkgs, ... }:
let
  cfg = config.my.services.bootAlerting;
in
{
  assertions = [
    {
      assertion = !cfg.enable || cfg.emergencyHook.networkTimeout > 0;
      message = "bootAlerting.emergencyHook.networkTimeout must be positive when enabled.";
    }
  ];
}
