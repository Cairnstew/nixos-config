{ config, lib, pkgs, ... }:
let
  cfg = config.my.services.bootHealth;
in
{
  assertions = [
    {
      assertion = !cfg.autoRollback.enable || cfg.enable;
      message = "bootHealth.autoRollback requires bootHealth.enable = true.";
    }
    {
      assertion = !cfg.enable || cfg.autoRollback.maxAttempts > 0;
      message = "bootHealth.autoRollback.maxAttempts must be positive when autoRollback is enabled.";
    }
  ];
}
