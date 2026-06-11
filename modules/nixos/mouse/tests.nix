{ config, lib, ... }:

let
  cfg = config.my.hardware.mouse;
in
{
  assertions = [
    {
      assertion = !cfg.enable || cfg.parameters.offset >= 0.0;
      message = "my.hardware.mouse.parameters.offset must be non-negative.";
    }
    {
      assertion = !cfg.enable || cfg.parameters.outputCap == null || cfg.parameters.outputCap > 0.0;
      message = "my.hardware.mouse.parameters.outputCap must be positive if set.";
    }
    {
      assertion = !cfg.enable || cfg.parameters.sensMultiplier == null || cfg.parameters.sensMultiplier >= 0.0;
      message = "my.hardware.mouse.parameters.sensMultiplier must be non-negative if set.";
    }
  ];
}
