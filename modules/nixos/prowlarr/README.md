# Prowlarr

Indexer manager/proxy that integrates with Sonarr, Radarr, and other *arr apps.

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `my.services.prowlarr.enable` | `false` | Enable Prowlarr |
| `my.services.prowlarr.port` | `9696` | Web UI port |
| `my.services.prowlarr.openFirewall` | `false` | Open firewall port |
| `my.services.prowlarr.disableAnalytics` | `true` | Disable telemetry |

## Usage

```nix
my.services.prowlarr = {
  enable = true;
  openFirewall = true;
};
```

## Notes

- Indexers configured in Prowlarr are auto-synced to connected Sonarr/Radarr instances.
- Uses upstream `services.prowlarr` NixOS module.
