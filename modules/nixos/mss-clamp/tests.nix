{ config, ... }:
let
  cfg = config.my.services.mssClamp;
in
{
  assertions = [
    {
      assertion = !cfg.enable || cfg.mss == null || (cfg.mss > 0 && cfg.mss <= 65535);
      message = "my.services.mssClamp.mss must be a valid MSS (1-65535) or null for auto-derivation.";
    }
    {
      assertion = !cfg.enable || cfg.interfaces != [ ];
      message = "my.services.mssClamp.interfaces must not be empty when enabled.";
    }
  ];
}
