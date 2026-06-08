# Tailscale

Tailscale mesh VPN with static SSH configuration derived from `config.nix`.

## Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `my.services.tailscale.enable` | `bool` | `false` | Enable Tailscale VPN |
| `my.services.tailscale.openFirewall` | `bool` | `true` | Open Tailscale UDP port |
| `my.services.tailscale.exitNode` | `bool` | `false` | Advertise as exit node |
| `my.services.tailscale.tags` | `[string]` | `[]` | ACL tags (e.g. `["tag:nixos"]` ) |
| `my.services.tailscale.ssh.enable` | `bool` | `false` | Enable Tailscale SSH server (--ssh) + client SSH config |
| `my.services.tailscale.ssh.user` | `string` | — | User whose SSH config is managed |
| `my.services.tailscale.ssh.publicKeyPath` | `path` | `null` | Path to tailscale SSH pub key |
| `my.services.tailscale.ssh.extraHostConfig` | `lines` | `""` | Extra SSH config per host |

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

SSH hosts are **statically generated** from `config.nix` at build time:

```nix
# config.nix
tailnet = {
  server = { ip = "100.x.x.x"; hostname = "server"; magicDnsName = "server.tailxxxx.ts.net"; };
  laptop = { ip = "100.x.x.x"; hostname = "laptop"; magicDnsName = "laptop.tailxxxx.ts.net"; };
};
```

Each entry generates:

```ssh-config
Host server
  HostName server.tailxxxx.ts.net
  IdentityFile /run/agenix/tailscale-ssh-key
  IdentitiesOnly yes
  ForwardAgent yes
```

## Secrets

Required agenix secrets (configured in `modules/nixos/secrets`):

| Secret | Purpose |
|--------|---------|
| `tailscale-authkey` | `tskey-auth-xxx` for node authentication |
| `tailscale-ssh-key` | SSH private key for tailnet access |

## Troubleshooting

Run smoke test: `systemctl start tailscale-smoke-test`

Check status: `tailscale status`
