{ config, lib, pkgs, flake, ... }:
let
  cfg = config.my.services.dscnix;
  inherit (lib) mkIf optionalAttrs;

  ianaToWindows = import ./timezone.nix;

  # ── Auto-derived values from NixOS host config ──────────────────────────

  autoDerivedDsc = lib.foldl lib.recursiveUpdate { } [
    # Hostname
    (optionalAttrs (cfg.autoDerive.enable && cfg.autoDerive.hostname) {
      registry.Hostname = {
        keyPath = "HKLM\\SYSTEM\\CurrentControlSet\\Services\\Tcpip\\Parameters";
        valueName = "NV Hostname";
        valueData = { String = config.networking.hostName; };
      };
    })

    # Dark mode
    (optionalAttrs (cfg.autoDerive.enable && cfg.autoDerive.darkMode) {
      registry.DarkMode = {
        keyPath = "HKCU\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Themes\\Personalize";
        valueName = "AppsUseLightTheme";
        valueData = { DWord = if (flake.config.preferences.darkMode or true) then 0 else 1; };
      };
    })

    # Timezone (via tzutil)
    (optionalAttrs (cfg.autoDerive.enable && cfg.autoDerive.timezone && config.time.timeZone != null) {
      runCommands.SetTimezone = {
        executable = "tzutil.exe";
        arguments = [ "/s" (ianaToWindows.${config.time.timeZone} or config.time.timeZone) ];
      };
    })
  ];

  # ── User-specified values take precedence ──────────────────────────────

  userDsc = {
    configurationName = cfg.configurationName;
    registry = cfg.registry;
    windowsServices = cfg.windowsServices;
    windowsFeatures = cfg.windowsFeatures;
    firewallRules = cfg.firewallRules;
    optionalFeatures = cfg.optionalFeatures;
    featuresOnDemand = cfg.featuresOnDemand;
    runCommands = cfg.runCommands;
    powerShellScripts = cfg.powerShellScripts;
    windowsPowerShellScripts = cfg.windowsPowerShellScripts;
    files = cfg.files;
    services = cfg.services;
    osInfo = cfg.osInfo;
    rebootPending = cfg.rebootPending;
  };

  # Merge: user values override auto-derived on a per-key basis
  mergedDsc = lib.recursiveUpdate autoDerivedDsc userDsc;

  # ── Generate DSC YAML via dscnix ───────────────────────────────────────

  dscYaml = flake.inputs.dscnix.lib.evalDscConfiguration [
    { dsc = mergedDsc; }
  ];

  dscConfigFile = pkgs.writeText "dscnix-desktop.yaml" dscYaml;
in
mkIf cfg.enable {
  my.services.dscnix.configFile = dscConfigFile;
  environment.etc."dscnix/desktop.yaml".source = dscConfigFile;
}
