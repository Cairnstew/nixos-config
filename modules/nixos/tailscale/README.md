# Tailscale

Tailscale mesh VPN. Client SSH config is generated at **runtime** from the live
tailnet device list (see [SSH Configuration](#ssh-configuration)).

## Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `my.services.tailscale.enable` | `bool` | `false` | Enable Tailscale VPN |
| `my.services.tailscale.openFirewall` | `bool` | `true` | Open Tailscale UDP port |
| `my.services.tailscale.exitNode` | `bool` | `false` | Advertise as exit node |
| `my.services.tailscale.acceptRoutes` | `bool` | `false` | Accept subnet routes advertised by other Tailscale nodes |
| `my.services.tailscale.mtu` | `int?` | `null` | WireGuard tunnel MTU (lower than default 1280 on constrained paths) |
| `my.services.tailscale.mtuReassertInterval` | `str` | `"5min"` | How often to re-assert the tunnel MTU (only when `mtu` is set) |
| `my.services.tailscale.tags` | `[string]` | `[]` | ACL tags (e.g. `["tag:nixos"]` ) |
| `my.services.tailscale.ssh.enable` | `bool` | `false` | Enable Tailscale SSH server (--ssh) + client SSH config |
| `my.services.tailscale.ssh.user` | `string` | — | User whose SSH config is managed |
| `my.services.tailscale.ssh.identityFile` | `path?` | `null` | SSH private key used to connect to tailnet machines (renders `IdentityFile` only when set) |
| `my.services.tailscale.ssh.publicKeyPath` | `path` | `null` | Path to tailscale SSH pub key |
| `my.services.tailscale.ssh.extraHostConfig` | `lines` | `""` | Extra SSH config per host |
| `my.services.tailscale.manager.enable` | `bool` | `false` | Tailscale auth key + ACL management via tailscale-manager (OAuth-based) |
| `my.services.tailscale.manager.tailnet` | `str` | `"-"` | Tailnet name (`-` auto-resolves from OAuth credential) |
| `my.services.tailscale.manager.authKeys` | `attrs` | `{}` | Declare multiple auth keys (replaces top-level `tags` when non-empty) |
| `my.services.tailscale.manager.policy.acls` | `[submodule]` | `[]` | Additional ACL rules beyond grants (accept/deny) |

## Usage

```nix
my.services.tailscale = {
  enable = true;
  tags = [ "tag:nixos" "tag:personal" ];
  ssh = {
    enable = true;
    user = "seanc";
    extraHostConfig = "ForwardAgent yes";
  };
};
```

## SSH Configuration

Client SSH config is generated at **runtime** by the `tailscale-ssh-config`
systemd unit from the **live** `tailscale status --json` device list
(`modules/nixos/tailscale/config.nix`). It is not derived from `config.nix` at
build time. Regenerate at any time with:

```console
systemctl start tailscale-ssh-config
```

For every tailnet device the generator writes a short-alias and full-DNSName
`Host` block:

```ssh-config
Host server
  HostName server.tailxxxx.ts.net
  IdentitiesOnly yes
```

`IdentityFile` + `IdentitiesOnly` lines are only rendered when
`my.services.tailscale.ssh.identityFile` is explicitly set (it defaults to
`null`). `extraHostConfig` lines (e.g. `ForwardAgent yes`) are appended inside
every block when set.

## Secrets

Required agenix secrets (configured in `modules/nixos/secrets`):

| Secret | Purpose |
|--------|---------|
| `tailscale-authkey` | `tskey-auth-xxx` for node authentication |
| `tailscale-live-key` | Tailscale pre-auth key (scope `deployment`) used by the tailscale-manager to provision auth keys |

## Troubleshooting

Run smoke test: `systemctl start tailscale-smoke-test`

Check status: `tailscale status`

## Related Modules

- **Imported by** [`modules/nixos/common.nix`](../common.nix) — enabled on all hosts via `my.*` options.
