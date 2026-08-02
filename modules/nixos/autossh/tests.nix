{ config, ... }:
let
  cfg = config.my.services.autosshReverse;
in
{
  assertions = [
    {
      assertion = !cfg.enable || cfg.bastion != "";
      message = "my.services.autosshReverse.bastion must be set (e.g. \"user@bastion.example.com\") when enabled.";
    }
  ];
}
