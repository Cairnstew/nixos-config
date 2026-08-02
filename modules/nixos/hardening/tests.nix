{ config, lib, ... }:
let
  cfg = config.my.system.hardening;
  isValidPercent = s: builtins.match "[0-9]+%" s != null;
in
{
  assertions = [
    {
      assertion = !cfg.enable || (cfg.zram.memoryPercent >= 1 && cfg.zram.memoryPercent <= 100);
      message = "my.system.hardening.zram.memoryPercent must be between 1 and 100 (got ${toString cfg.zram.memoryPercent}).";
    }
    {
      assertion = !cfg.enable || (cfg.oomd.swapUsedLimit == "" || isValidPercent cfg.oomd.swapUsedLimit);
      message = "my.system.hardening.oomd.swapUsedLimit must be a percentage string (e.g. \"90%\").";
    }
    {
      assertion = !cfg.enable || isValidPercent cfg.oomd.defaultMemoryPressureLimit;
      message = "my.system.hardening.oomd.defaultMemoryPressureLimit must be a percentage string (e.g. \"60%\").";
    }
    {
      assertion = !cfg.enable || cfg.protectedUnits != [ ];
      message = "my.system.hardening.protectedUnits must not be empty when enabled.";
    }
    {
      assertion = !cfg.enable || lib.all (u: lib.hasSuffix ".service" u) cfg.protectedUnits;
      message = "my.system.hardening.protectedUnits entries must be systemd unit names ending in .service.";
    }
    {
      assertion = !cfg.enable || lib.all isValidPercent (lib.attrValues cfg.cpuQuota);
      message = "my.system.hardening.cpuQuota values must be percentage strings (e.g. \"400%\" = 4 cores).";
    }
  ];
}
