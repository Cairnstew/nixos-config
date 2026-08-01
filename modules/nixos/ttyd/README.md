# ttyd Web Terminal

Browser-based emergency SSH console. Useful when the SSH *client* is the
problem (e.g. you're on a borrowed machine) or as a fallback shell. Because
it's a web page it can ride a different path than your SSH client.

**Independence caveat**: binding to `127.0.0.1` (default) and exposing via the
reverse proxy is NOT independent of Tailscale. Bind to a ZeroTier/LAN address
to get a Tailscale-independent path.

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `my.services.ttyd.enable` | `false` | Enable ttyd |
| `my.services.ttyd.port` | `7681` | Listen port |
| `my.services.ttyd.address` | `"127.0.0.1"` | Bind IP/interface (e.g. ZeroTier IP) |
| `my.services.ttyd.username` | `null` | Basic-auth username (required) |
| `my.services.ttyd.passwordFile` | `null` | Basic-auth password file (required, agenix path) |
| `my.services.ttyd.writeable` | `true` | Allow writing to the terminal |
| `my.services.ttyd.entrypoint` | `["/run/current-system/sw/bin/bash"]` | Command run (root shell by default) |
| `my.services.ttyd.user` | `null` | Unix user (null = root) |
| `my.services.ttyd.maxClients` | `2` | Max concurrent clients |
| `my.services.ttyd.openFirewall` | `false` | Open the port in the firewall |
| `my.services.ttyd.proxyUpstream` | `true` | Register with the reverse proxy |

## Usage Example

```nix
my.services.ttyd = {
  enable = true;
  address = "192.168.191.54"; # ZeroTier IP — Tailscale-independent
  username = "seanc";
  passwordFile = config.age.secrets."ttyd-password".path;
  openFirewall = true;
};
```

## Notes

- Basic auth + binding to a mesh interface + writeable shell = treat the
  password as a real credential.
- Available at `https://server.tailnet/.../ttyd/` via the reverse proxy too.
