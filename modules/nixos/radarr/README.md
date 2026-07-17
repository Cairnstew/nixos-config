# Radarr

Movie automatic download and management. Integrates with Prowlarr for indexer access.

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `my.services.radarr.enable` | `false` | Enable Radarr |
| `my.services.radarr.port` | `7878` | Web UI port |
| `my.services.radarr.openFirewall` | `false` | Open firewall port |
| `my.services.radarr.disableAnalytics` | `true` | Disable telemetry |

## Usage

```nix
my.services.radarr = {
  enable = true;
  openFirewall = true;
};
```

## Notes

- Uses upstream `services.radarr` NixOS module.
- Point Prowlarr at Radarr for auto-synced indexers.
