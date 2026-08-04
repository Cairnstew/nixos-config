# OpenCode Web

Runs [`opencode web`](https://opencode.ai/docs/web/) as a systemd service —
one instance per repo synced by [`gitreposync`](../gitreposync/) — so you get
browser access to opencode for your NixOS config (and any other synced repos)
without a terminal.

## How it works

- The opencode server loads projects per-request via the
  `x-opencode-directory` header and defaults to the process working directory,
  so each instance is started with `WorkingDirectory` set to the gitRepoSync
  checkout of its repo. The web UI opens on that repo by default.
- The server runs as the configured user, so it picks up that user's opencode
  config, `auth.json`, skills, tools and MCP servers.
- The browser-open the `web` command attempts is a no-op (`BROWSER=/bin/true`),
  and the built-in `OPENCODE_SERVER_PASSWORD` basic auth is wired from an
  optional `passwordFile`.

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `my.services.opencodeWeb.enable` | `false` | Enable opencode web |
| `my.services.opencodeWeb.user` | `null` | User to run the servers as (must have opencode configured) |
| `my.services.opencodeWeb.repos` | `["nix-config"]` | gitRepoSync repo names to serve — one instance each |
| `my.services.opencodeWeb.instances.<repo>.port` | auto | Per-instance port (basePort + index) |
| `my.services.opencodeWeb.instances.<repo>.servePort` | auto | Per-instance tailnet HTTPS port |
| `my.services.opencodeWeb.instances.<repo>.hostname` | global | Per-instance bind address |
| `my.services.opencodeWeb.instances.<repo>.openFirewall` | global | Open this port in the firewall |
| `my.services.opencodeWeb.instances.<repo>.extraArgs` | `[]` | Extra `opencode web` args (e.g. `--cors`) |
| `my.services.opencodeWeb.basePort` | `4200` | First auto-allocated local port |
| `my.services.opencodeWeb.hostname` | `127.0.0.1` | Default bind address |
| `my.services.opencodeWeb.openFirewall` | `false` | Open instance ports in the firewall |
| `my.services.opencodeWeb.passwordFile` | `null` | File with `OPENCODE_SERVER_PASSWORD` (basic auth) |
| `my.services.opencodeWeb.tailnetServe.enable` | `true` | Expose instances on the tailnet via `tailscale serve` |
| `my.services.opencodeWeb.tailnetServe.basePort` | `8443` | First tailnet serve HTTPS port |
| `my.services.opencodeWeb.dashboard.enable` | `true` | Add an OpenCode section to the proxy dashboard |
| `my.services.opencodeWeb.dashboard.baseUrl` | `http://localhost` | Base URL for dashboard instance links |

## Usage Example

```nix
my.services.opencodeWeb = {
  enable = true;
  user = "seanc";
  repos = [ "nix-config" "sillytavern" ]; # each becomes an instance
};
```

## Tailnet access

Each repo is exposed on its own tailnet HTTPS port via
`tailscale serve --https <port> http://127.0.0.1:<backendPort>`:

- `nix-config` → `https://<host>.ts.net:8443/`
- `sillytavern` → `https://<host>.ts.net:8444/`

The dashboard's OpenCode section builds these links automatically from the
current page's hostname, so clicking an instance card (or a session) from any
tailnet device opens the right URL. When the dashboard is viewed locally
(`http://localhost:8081`) it falls back to the direct `http://localhost:<port>/`
link.

## Notes

- **Remote access**: instances bind `127.0.0.1` by default; tailscale serve
  proxies the tailnet → localhost, so the backend never needs to bind
  `0.0.0.0`. `tailscaleServe.enable` defaults `true` (modern Tailscale serve
  supports arbitrary `--https` ports). A warning is emitted when tailnet access
  is on but no `passwordFile` is set — add one for basic auth so any tailnet
  node can't use your API keys unchecked.
- **First boot**: gitRepoSync clones the repo; the service waits up to ~3 min
  for the checkout before giving up (it then restarts and retries).
- The web-UI SPA is **not** proxied under a subpath (its asset URLs are
  root-absolute), so dashboard cards link straight to the tailnet HTTPS port
  (or `http://<host>:<port>/` locally) rather than through Caddy.
- Enabled by the `development` profile with `user` defaulting to the primary
  user, serving the `nix-config` repo by default.

## Related

- `modules/nixos/gitreposync/` — repo sync the working directories come from
- `modules/home/opencode/` — user-level opencode config this service inherits
- `modules/nixos/proxy/` — dashboard section / session proxying
