{ config, lib, ... }:
let
  cfg = config.my.system.hardening;
  isValidPercent = s: builtins.match "[0-9]+%" s != null;
  isValidMemoryLimit = s:
    s == "infinity"
    || isValidPercent s
    || builtins.match "[0-9]+([KMGT]i?B?)" s != null;
  unitName = unit: lib.removeSuffix ".service" unit;
  effective = unit: config.systemd.services.${unitName unit}.serviceConfig;
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
      assertion = !cfg.enable || cfg.oomd.defaultMemoryPressureDurationSec != "";
      message = "my.system.hardening.oomd.defaultMemoryPressureDurationSec must be a systemd time span (e.g. \"30s\").";
    }
    {
      # oomd's key is `...DurationSec`; `...DurationUSec` is rejected and
      # silently replaced by the built-in default.
      assertion = !cfg.enable || !cfg.oomd.enable
        || (config.systemd.oomd.settings.OOM ? DefaultMemoryPressureDurationSec);
      message = "systemd-oomd is missing DefaultMemoryPressureDurationSec — the ...USec spelling is ignored by systemd.";
    }
    {
      assertion = !cfg.enable || cfg.protectedUnits != [ ];
      message = "my.system.hardening.protectedUnits must not be empty when enabled.";
    }
    {
      # Regression guard for the real bug: `systemd.services."sshd.service"`
      # creates `sshd.service.service`, leaving `sshd` with OOMScoreAdjust=0.
      assertion = !cfg.enable || lib.all
        (u: (effective u).OOMScoreAdjust == -1000 && (effective u).ManagedOOMPreference == "omit")
        cfg.protectedUnits;
      message = "my.system.hardening.protectedUnits must merge into the real <name>.service units (no .service suffix) with OOMScoreAdjust=-1000 and ManagedOOMPreference=omit.";
    }
    {
      assertion = !cfg.enable || lib.all isValidPercent (lib.attrValues cfg.cpuQuota);
      message = "my.system.hardening.cpuQuota values must be percentage strings (e.g. \"400%\" = 4 cores).";
    }
    {
      assertion = !cfg.enable || lib.all isValidMemoryLimit [
        cfg.workloadLimits.userSliceMemoryHigh
        cfg.workloadLimits.userSliceMemoryMax
        cfg.workloadLimits.nixDaemonMemoryHigh
        cfg.workloadLimits.nixDaemonMemoryMax
        cfg.workloadLimits.systemSliceMemoryMin
      ];
      message = "my.system.hardening.workloadLimits values must be systemd memory limits (e.g. \"65%\" or \"8G\").";
    }
    {
      assertion = !cfg.enable || !cfg.workloadLimits.enable
        || (config.systemd.slices."user".sliceConfig.MemoryMax or null) == cfg.workloadLimits.userSliceMemoryMax;
      message = "workloadLimits.userSliceMemoryMax did not land on systemd.slices.\"user\".sliceConfig (the key is \"user\", not \"user.slice\").";
    }
    {
      assertion = !cfg.enable || !cfg.workloadLimits.enable
        || (config.systemd.services.nix-daemon.serviceConfig.MemoryMax or null) == cfg.workloadLimits.nixDaemonMemoryMax;
      message = "workloadLimits.nixDaemonMemoryMax did not land on systemd.services.nix-daemon.serviceConfig.";
    }
    {
      assertion = !cfg.enable || !cfg.earlyoom.enable || config.services.earlyoom.enable;
      message = "my.system.hardening.earlyoom.enable is true but services.earlyoom.enable is false.";
    }
    {
      assertion = !cfg.enable || cfg.watchdog.runtimeSec == null
        || (config.systemd.settings.Manager.RuntimeWatchdogSec or null) == cfg.watchdog.runtimeSec;
      message = "my.system.hardening.watchdog.runtimeSec did not land on systemd.settings.Manager.RuntimeWatchdogSec.";
    }
  ];
}
