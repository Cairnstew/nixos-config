# Tor SSH (onion service)

Tor onion-service SSH. The box makes *outbound* Tor circuits and publishes an
onion address — so it works even when Tailscale, ZeroTier, all inbound ports,
and public IP are dead. This is the most independent emergency path available
with no extra hardware.

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `my.services.torSsh.enable` | `false` | Enable onion-service SSH |
| `my.services.torSsh.onionPort` | `22022` | Onion service port |
| `my.services.torSsh.localPort` | `22` | Local SSH port |
| `my.services.torSsh.secretKey` | `null` | Persistent v3 key path (else Tor generates + persists) |
| `my.services.torSsh.authorizedClients` | `[]` | v3 client-auth public keys (optional hardening) |
| `my.services.torSsh.openFirewall` | `false` | Should stay false (no inbound ports needed) |

## Usage Example

```nix
my.services.torSsh.enable = true;
```

## Client Access

```sh
ssh -o ProxyCommand="nc -X 5 -x 127.0.0.1:9050 %h %p" -p 22022 seanc@<onion-address>.onion
```

The onion address is written by Tor to `/var/lib/tor/onion/ssh/hostname`
(persists across reboots on this host). SSH password auth stays off — only
pubkey is allowed (onion addresses are semi-public).

## Notes

- No `services.tor.relay.enable` needed — onion services render regardless.
- Persist a fixed key via agenix (`secretKey`) if you must guarantee the
  address across full storage wipes.
