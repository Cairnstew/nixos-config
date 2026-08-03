# SSH

SSH server with auto-generated root key and authorized keys management.

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `my.services.ssh.enable` | `false` | Enable SSH daemon |
| `my.services.ssh.authorizedKeys` | `[]` | Root authorized keys |
| `my.services.ssh.lanSubnets` | `[]` | Subnets where password/keyboard-interactive auth is always allowed as a LAN fallback (e.g. `["192.168.1.0/24"]`) |

## Usage

```nix
my.services.ssh = {
  enable = true;
  authorizedKeys = [ "ssh-ed25519 AAAA..." ];
};
```

## Related Modules

- **Imported by** [`modules/nixos/common.nix`](../common.nix) — enabled on all hosts via `my.*` options.
