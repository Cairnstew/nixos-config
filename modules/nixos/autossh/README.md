# AutoSSH Reverse Tunnel

Phone-home reverse SSH tunnel to a bastion host you own. The box keeps an
outbound SSH connection (`-R remotePort:localhost:22`) alive with autossh.
When every mesh VPN is down, reach it via plain internet SSH:

```sh
ssh -p 22022 seanc@bastion.example.com
```

This rides plain SSH — an independent transport from Tailscale/ZeroTier.

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `my.services.autosshReverse.enable` | `false` | Enable the tunnel |
| `my.services.autosshReverse.bastion` | `""` | `user@host` bastion to tunnel to (required) |
| `my.services.autosshReverse.user` | `"root"` | Local user the tunnel runs as |
| `my.services.autosshReverse.remotePort` | `22022` | Remote port on the bastion |
| `my.services.autosshReverse.localPort` | `22` | Local SSH port |
| `my.services.autosshReverse.monitoringPort` | `20001` | autossh monitoring port |
| `my.services.autosshReverse.identityFile` | `"/root/.ssh/id_ed25519"` | SSH identity for the bastion |
| `my.services.autosshReverse.serverAliveInterval` | `15` | Keepalive interval |

## Usage Example

```nix
my.services.autosshReverse = {
  enable = true;
  bastion = "seanc@bastion.example.com";
};
```

## Notes

- The bastion's `sshd` must allow `GatewayPorts` (or restrict to localhost)
  and the SSH key must be authorized there.
- `StrictHostKeyChecking=accept-new` auto-trusts the bastion host key once.
