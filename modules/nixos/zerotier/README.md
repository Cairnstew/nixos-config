# ZeroTier

ZeroTier One mesh VPN, configured as a Tailscale fallback.

## Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `my.services.zerotier.enable` | bool | false | Enable ZeroTier |
| `my.services.zerotier.networks` | list of string | `[]` | Network IDs to join |
| `my.services.zerotier.localConf` | null or attrs | null | `local.conf` overrides |
| `my.services.zerotier.openFirewall` | bool | true | Open UDP port 9993 |
| `my.services.zerotier.package` | null or package | null | Package override |

## Usage

```nix
my.services.zerotier = {
  enable = true;
  networks = [ "8056c2e21c000001" ];
};
```

## Dependencies

- **NixOS modules**: services.zerotierone, networking.firewall
- **Flake inputs**: none

## Notes

- Not auto-started at boot — `wantedBy` is cleared so the tailscale-watchdog manages start/stop.
- `Restart` is forced to `on-failure` with 5 second delay for fallback reliability.
- Firewall UDP port 9993 is opened by default.
