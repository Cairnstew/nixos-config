{ config, lib, ... }:
let
  cfg = config.my.services.emailAlerts;
in
{
  config = lib.mkIf cfg.enable {
    age.secrets."${cfg.secretName}" = { };
  };
}
