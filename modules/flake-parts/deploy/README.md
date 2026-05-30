# Deploy

nixos-anywhere deploy app and interactive wizard for remote NixOS installation.

## Apps

| App | Command | Description |
|-----|---------|-------------|
| `deploy` | `nix run .#deploy -- <host> [<addr>]` | Deploy NixOS to a remote machine via nixos-anywhere |
| `deploy-wizard` | `nix run .#deploy-wizard -- <host>` | Interactive wizard with disk selection and partition creation |

## just commands

```bash
just deploy desktop          # Deploy via Tailscale
just deploy server 10.0.0.5 # Deploy via raw IP
just deploy-wizard desktop   # Interactive wizard
just register-host desktop <ip>  # Register host key with agenix
```

## disk-config.nix

If `configurations/nixos/<host>/disk-config.nix` exists, the deploy app passes
`--disk-config` to nixos-anywhere for automatic partitioning via disko.
The wizard detects existing NixOS partitions by label and uses `--disko-mode mount`
to avoid reformatting.

## Files

| File | Purpose |
|------|---------|
| `default.nix` | Import manifest (auto-imported by flake) |
| `deploy.nix` | `apps.deploy` — nixos-anywhere wrapper |
| `deploy-wizard.nix` | `apps.deploy-wizard` — interactive installer |
| `meta.nix` | Module metadata |
| `tests.nix` | Assertions |
