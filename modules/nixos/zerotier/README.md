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
| `my.services.zerotier.mtu` | null or int | null | Clamp every `zt*` interface to this MTU (see below) |

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
- `mtu` adds `zerotier-mtu.service`, a oneshot that waits for `zt*` interfaces
  (up to 300 s, they appear only after the network join) and runs
  `ip link set dev <if> mtu <mtu>` on each. It is pulled in by
  `zerotierone.service` and `partOf` it, so the clamp is re-applied after every
  ZeroTier restart — the devices come back at the default 2800.

### Why clamp the MTU

ZeroTier advertises a 2800-byte MTU regardless of the real path. When it
relays traffic (or a WAN hop is smaller) the path may carry only ~1300 bytes,
so a single large datagram is fragmented past what the path delivers and
silently dropped, while tiny control packets keep flowing. The connection looks
healthy in both logs and answers `ping`, but the protocol waits forever for a
payload that never arrives — exactly what Project Zomboid does: the
`connection-details` packet carries the whole server description plus hundreds
of Workshop/mod ids, and the client stalls right after it.

Measure the path (`ping -M do -s <payload> <peer>`), then set `mtu` on **both**
ends; fragments are dropped on the way *out* of the oversized sender.

## Related Modules

- **Imported by** [`modules/nixos/common.nix`](../common.nix) — enabled on all hosts via `my.*` options.
