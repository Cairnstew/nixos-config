{ config, lib, ... }:
let
  cfg = config.my.services.hedgedoc;
in
{
  assertions = [
    {
      assertion = !cfg.enable || cfg.domain != "";
      message = "my.services.hedgedoc.domain must be set when enabled.";
    }
    {
      assertion = !cfg.enable || (config.age.secrets ? "hedgedoc.env");
      message = "HedgeDoc requires the 'hedgedoc.env' secret to be defined in age.secrets.";
    }
  ];
}
