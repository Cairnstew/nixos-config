{ config, lib, ... }:
let
  cfg = config.my.services.backup-source;
in
{
  assertions = [
    {
      assertion = !cfg.enable || cfg.targetHost != "";
      message = "my.services.backup-source: targetHost must not be empty when enabled.";
    }
    {
      assertion = !cfg.enable || cfg.user != "";
      message = "my.services.backup-source: user must not be empty when enabled.";
    }
    {
      assertion = !cfg.enable || builtins.attrNames cfg.jobs != [ ];
      message = "my.services.backup-source: at least one job must be defined when enabled.";
    }
    {
      assertion = !cfg.enable || (lib.all (j: j.paths != [ ]) (lib.attrValues cfg.jobs));
      message = "my.services.backup-source: every job must define non-empty paths.";
    }
  ];
}
