{ config, lib, ... }:
let
  cfg = config.my.profiles;
in
{
  assertions = [
    {
      assertion = !(cfg.gpu.mesa.enable && cfg.gpu.nvidia.enable);
      message = "Cannot enable both Mesa and NVIDIA GPU profiles.";
    }
  ];
}
