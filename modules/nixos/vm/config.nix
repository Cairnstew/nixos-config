{ config, lib, ... }:
let
  cfg = config.my.vm;
in
{
  # This module only declares options — no active config is added.
  # The flake-parts VM builder reads cfg.enable, cfg.extraConfig, etc.
  # to generate per-host VM packages.
  #
  # A no-op assertion ensures the module is properly evaluated:
  assertions = [
    {
      assertion = true;
      message = "my.vm options loaded.";
    }
  ];
}
