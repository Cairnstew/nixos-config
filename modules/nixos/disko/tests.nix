{ config, lib, flake, ... }:
let
  cfg = config.my.disko.dualBoot;
  diskoMod = flake.inputs.disko.nixosModules.default;
  selfMod = flake.inputs.self.nixosModules;
  diskoOpts = ./options.nix;
  diskoConfig = ./config.nix;
in
{
  assertions = [
    {
      assertion = !cfg.enable || cfg.disk != "";
      message = "my.disko.dualBoot.disk must not be empty when enabled.";
    }
    {
      assertion = !cfg.enable || cfg.mode == "fresh" || (cfg.mode == "useExisting" && cfg.nixosPartition != null);
      message = "my.disko.dualBoot.nixosPartition is required when mode = \"useExisting\".";
    }
    {
      assertion = !cfg.enable || cfg.mode != "fresh" || cfg.windowsSizeGB > 0;
      message = "my.disko.dualBoot.windowsSizeGB must be positive in fresh mode.";
    }
    {
      assertion = !cfg.enable || cfg.mode != "fresh" || cfg.espSizeGB > 0;
      message = "my.disko.dualBoot.espSizeGB must be positive in fresh mode.";
    }
    {
      assertion = !cfg.enable || cfg.mode != "fresh" || cfg.msrSizeMB > 0;
      message = "my.disko.dualBoot.msrSizeMB must be positive in fresh mode.";
    }
  ];


}
