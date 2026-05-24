# SSH

SSH server with auto-generated root key and authorized keys management.

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `my.services.ssh.enable` | `false` | Enable SSH daemon |
| `my.services.ssh.authorizedKeys` | `[]` | Root authorized keys |

## Usage

```nix
my.services.ssh = {
  enable = true;
  authorizedKeys = [ "ssh-ed25519 AAAA..." ];
};
```
