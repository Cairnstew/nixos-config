# dscnix — DSC v3 YAML Generation

Generate PowerShell Desired State Configuration v3 YAML documents from your
NixOS configuration. Lets you define Windows registry keys, services, firewall
rules, and more using Nix, with values derived from your host config.

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `my.services.dscnix.enable` | `false` | Enable DSC YAML generation |
| `my.services.dscnix.configurationName` | `"DSCConfiguration"` | DSC document name |
| `my.services.dscnix.autoDerive.enable` | `true` | Auto-derive values from host config |
| `my.services.dscnix.autoDerive.hostname` | `true` | Derive Windows hostname from NixOS |
| `my.services.dscnix.autoDerive.darkMode` | `true` | Derive dark mode from preferences |
| `my.services.dscnix.autoDerive.timezone` | `true` | Derive timezone via tzutil |
| `my.services.dscnix.registry.*` | `{}` | Windows Registry keys/values |
| `my.services.dscnix.windowsServices.*` | `{}` | Windows native services |
| `my.services.dscnix.windowsFeatures.*` | `{}` | Windows features (legacy) |
| `my.services.dscnix.firewallRules.*` | `{}` | Firewall rules (read-only) |
| `my.services.dscnix.optionalFeatures.*` | `{}` | Optional features (read-only) |
| `my.services.dscnix.runCommands.*` | `{}` | Commands to run on set |
| `my.services.dscnix.files.*` | `{}` | File resources |
| `my.services.dscnix.services.*` | `{}` | Legacy service resources |
| `my.services.dscnix.osInfo.*` | `{}` | OS assertion (read-only) |
| `my.services.dscnix.rebootPending.*` | `{}` | Reboot pending check (read-only) |
| `my.services.dscnix.configFile` | `null` | (readOnly) The generated YAML derivation |

## Usage

```nix
my.services.dscnix = {
  enable = true;
  configurationName = "MyWindowsDSC";

  # Auto-derived values handle hostname, dark mode, timezone
  # Just add extras specific to this host:
  registry = {
    "DisableCortana" = {
      keyPath = "HKLM\\SOFTWARE\\Policies\\Microsoft\\Windows\\Windows Search";
      valueName = "AllowCortana";
      valueData = { DWord = 0; };
    };
  };

  optionalFeatures = {
    "Microsoft-Windows-Subsystem-Linux" = { state = "Installed"; };
    "VirtualMachinePlatform" = { state = "Installed"; };
  };
};
```

## Output

The generated YAML is available at:
- **Nix store**: `config.my.services.dscnix.configFile`
- **Filesystem**: `/etc/dscnix/desktop.yaml`

## Auto-derived Values

| Value | Source | DSC Output |
|-------|--------|------------|
| Hostname | `config.networking.hostName` | Registry `HKLM\...\NV Hostname` |
| Dark mode | `config.preferences.darkMode` | Registry `HKCU\...\AppsUseLightTheme` |
| Timezone | `config.time.timeZone` | `tzutil /s "Windows TZ Name"` |

## Notes

- DSC v3.1.0 has some read-only resource types (firewall rules, optional features).
  They can be tested/asserted but not set.
- The IANA→Windows timezone mapping covers ~300 timezone identifiers.
  If your TZ is not found, the raw IANA name is passed to tzutil as a fallback.
