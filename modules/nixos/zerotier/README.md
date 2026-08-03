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

- Always-on at boot — `wantedBy = [ "multi-user.target" ]` (independent recovery mesh, not managed by tailscale-watchdog).
- `Restart` is forced to `on-failure` with 5 second delay for fallback reliability.
- Firewall UDP port 9993 is opened by default.

## Related Modules

- **Imported by** [`modules/nixos/common.nix`](../common.nix) — enabled on all hosts via `my.*` options.
