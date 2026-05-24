# SSH

SSH client configuration with key generation, agent management, and per-host match blocks.

## Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | bool | false | Enable SSH configuration |
| `keyType` | enum | `"ed25519"` | Key type (ed25519, rsa, ecdsa) |
| `keyPath` | str | `"~/.ssh/id_ed25519"` | Path to SSH key |
| `email` | str | flake config email | Email for key comment |
| `addKeysToAgent` | bool | true | Auto-add keys to agent |
| `extraConfig` | lines | `""` | Extra SSH config lines |
| `generateKey` | bool | true | Auto-generate key on activation |
| `enableAgent` | bool | Linux-only | Enable ssh-agent service |
| `identityAgent` | null/str | null | IdentityAgent for Host * block |
| `includes` | list of str | [ ] | Files to Include in ssh config |
| `matchBlocks` | attrs | { } | Per-host match blocks |

## Usage

```nix
my.services.ssh = {
  enable = true;
  keyType = "ed25519";
  email = "user@example.com";
};
```

### With a match block

```nix
my.services.ssh.matchBlocks.my-server = {
  host = "myserver.example.com";
  user = "admin";
  port = 2222;
  identityFile = "~/.ssh/myserver";
};
```

## Notes

- Key generation runs as a home-manager activation script.
- The `identityAgent` option is intended for 1Password or other SSH agents.
- Other modules can contribute to `includes` and `identityAgent` via `my.services.ssh`.
