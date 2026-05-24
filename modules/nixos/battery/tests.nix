{ config, lib, ... }:
let
  cfg = config.my.system.battery;
in
{
  # ── L0: Nix assertions ──────────────────────────────────────────────────────
  assertions = [
    {
      assertion = !cfg.enable || !cfg.disableSuspend ||
        (cfg.lidSwitch == "ignore" && cfg.lidSwitchExternalPower == "ignore" && cfg.lidSwitchDocked == "ignore");
      message = "my.system.battery.disableSuspend requires all lidSwitch options to be set to 'ignore' (suspend targets will be disabled).";
    }
  ];
}
