# 1Password

Desktop app, CLI, and SSH agent integration.

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `my.programs._1password.enable` | `true` | Enable 1Password |

## Usage

```nix
my.programs._1password.enable = true;
```

## Related Modules

- **Imported by** [`modules/nixos/common.nix`](../common.nix) — enabled on all hosts via `my.*` options.
