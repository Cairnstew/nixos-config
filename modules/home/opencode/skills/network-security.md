# Network Security

> Skill for Tailscale ACL/tag/grant policy and the Caddy-based reverse-proxy module in this NixOS configuration

## Overview

Two layers make up this repo's network security:

1. **Tailscale** (`modules/nixos/tailscale/`) — mesh VPN, device tags, and a
   declarative policy (grants / SSH rules / ACLs / groups / node attrs) that
   `tailscale-manager` applies to the tailnet via Terraform.
2. **Proxy** (`modules/nixos/proxy/`) — a Caddy reverse proxy fronting web
   services on one port, optionally exposed over the tailnet with
   `tailscale serve`.

Both are configured through `my.*` options — never by editing ACL JSON or a
Caddyfile by hand.

## Tailscale ACL Model

The tailnet ACL model is expressed as a **structured policy** under
`my.services.tailscale.manager.policy` (options declared in
`modules/nixos/tailscale/options.nix:457-579`). Enabling it requires
`my.services.tailscale.manager.enable` (options.nix:414) and
`my.services.tailscale.manager.policy.enable` (options.nix:458). Device tags
live at `my.services.tailscale.tags` (options.nix:377-382).

The policy block manages these sub-options:

| Option | Type | Purpose |
|--------|------|---------|
| `policy.tagOwners` | `attrsOf (listOf str)` | Who can assign which tags (options.nix:460) |
| `policy.grants` | `listOf grantSubmodule` | Access grants: `src`/`dst`/`ip` (options.nix:479) |
| `policy.ssh` | `listOf sshSubmodule` | SSH rules: `action` accept/check/match (options.nix:485) |
| `policy.acls` | `listOf aclSubmodule` | Extra accept/deny rules (options.nix:491) |
| `policy.groups` | `attrsOf (listOf str)` | Named user groups (options.nix:497) |
| `policy.hosts` | `attrsOf str` | Named IP/CIDR aliases (options.nix:506) |
| `policy.ipsets` | `attrsOf (listOf str)` | Named IP collections (options.nix:515) |
| `policy.postures` | `attrsOf (listOf str)` | Device posture expressions (options.nix:521) |
| `policy.nodeAttrs` | `listOf nodeAttrsSubmodule` | Per-device attrs: NextDNS, Funnel, etc. (options.nix:527) |
| `policy.appConnectors` | `listOf appConnectorSubmodule` | Declarative app connectors (options.nix:533) |
| `policy.autoApprovers` | `autoApproversSubmodule` | Route/exit-node approval bypass (options.nix:542) |
| `policy.tests` | `listOf testSubmodule` | ACL/grant assertion tests (options.nix:567) |
| `policy.sshTests` | `listOf sshTestSubmodule` | SSH assertion tests (options.nix:573) |
| `policy.derpMap` | `nullOr submodule` | Custom DERP relay regions (options.nix:548) |
| `policy.interNodePorts` | `listOf str` | Convenience: generates `tag:nixos`→`tag:nixos` grants (options.nix:467) |
| `policy.extraConfig` | freeform | Merge-in extra upstream policy keys (manager.nix:43) |

### ACL submodule shape

Each entry in `policy.acls` is an `aclSubmodule`
(`modules/nixos/tailscale/options.nix:122-143`):

```nix
{
  action = "accept";               # "accept" | "deny" (default "accept")
  src = [ "tag:ci" ];              # source hosts, tags, or user groups
  dst = [ "tag:ci" ];              # destination hosts, tags, or ports
  proto = null;                    # optional protocol filter ("tcp", "udp", "icmp")
}
```

### Grant submodule shape

`policy.grants` entries use `grantSubmodule` (options.nix:50-82): `src` and
`dst` are lists of hosts/tags, `ip` is a list of IPs or ports
(`"tcp:22"`, `"100.0.0.0/8"`), plus optional `app` (app-layer capabilities),
`via` (subnet routers), and `srcPosture` (posture checks).

### How policy maps to the Tailscale API

`modules/nixos/tailscale/manager.nix` forwards every `cfg.policy.*` value into
the upstream `services.tailscale-manager.policy` attrset, which serializes to
the tailnet ACL JSON:

- `manager.nix:29` — `acls = cfg.policy.acls;`
- `manager.nix:19-27` — `grants` is the `interNodePorts`-generated
  `tag:nixos`→`tag:nixos` grants concatenated with `cfg.policy.grants`
- `manager.nix:30-38` — `groups`, `hosts`, `ipsets`, `postures`, `nodeAttrs`,
  `appConnectors`, `autoApprovers`, `derpMap`
- `manager.nix:43` — `} // cfg.policy.extraConfig;` merges freeform overrides

The whole thing is gated on `cfg.enable` (`services.tailscale-manager.enable = true`),
reads its OAuth credential from `config.age.secrets.tailscale-oauthkey.path`
(manager.nix:15), and requires `tailscale-manager init` to have run — see the
GOTCHAS below.

### Assertion tests

`policy.tests` and `policy.sshTests` are assertion tests: **policy is rejected
if they fail** (options.nix:570, 576). Each test simulates a src→dst/proto
access attempt. Add tests when you add grants, not as an afterthought.

## Reading / Modifying the Policy

To audit the current policy:

```bash
# Structured policy as evaluated for a host
nix eval .#nixosConfigurations.server.config.my.services.tailscale.manager.policy --json
```

To add a grant (e.g. allow a `tag:ci` node to reach SSH on all `tag:nixos`
nodes), add to `policy.grants` in the host config or the tailscale module:

```nix
my.services.tailscale.manager.policy = {
  enable = true;
  grants = [
    {
      src = [ "tag:ci" ];
      dst = [ "tag:nixos" ];
      ip = [ "tcp:22" ];
    }
  ];
  tests = [
    { src = "tag:ci"; dst = "tag:nixos"; proto = "tcp"; accept = [ "22" ]; }
  ];
};
```

Per-module or per-host overrides use the same merge rules as any `my.*` option
(`lib.mkDefault` in shared modules, plain assignment in host configs). Never
hand-edit the applied ACL JSON — regenerate from the structured policy.

## tailscale-manager Tool

The `tailscale-manager` opencode tool is **status-only** — it runs
`sudo tailscale-manager status --json` (see
`modules/home/opencode/tools/tailscale-manager.ts:8`). It does **not** apply
policy. All ACL/tag/grant changes are made via
`my.services.tailscale.manager.policy.*` config + deploy, not through the tool.

## Proxy Upstreams (Caddy)

`my.services.proxy` (`modules/nixos/proxy/options.nix`) is a unified Caddy
reverse proxy. Key options:

| Option | Default | Purpose |
|--------|---------|---------|
| `my.services.proxy.enable` | `false` | Enable Caddy + generated Caddyfile |
| `my.services.proxy.port` | `8081` | Caddy listen port |
| `my.services.proxy.listenAddresses` | `[ "127.0.0.1" ]` | Interfaces Caddy binds to |
| `my.services.proxy.upstreams` | `{}` | `attrsOf` of service upstreams (modules auto-register) |
| `my.services.proxy.tailscaleServe.enable` | `false` | `tailscale serve` → `:443` → Caddy |
| `my.services.proxy.dashboard.enable` | `true` | Dashboard static page at root `/` |
| `my.services.proxy.extraConfig` | `""` | Raw Caddyfile lines appended to the site block |

### Upstream registration

Services register themselves into `my.services.proxy.upstreams.<name>`
(options.nix:296-303). Each upstream (`upstreamType`, options.nix:3-88):

- `host` (default `"127.0.0.1"`), `port`, `path` (URL prefix, e.g. `/risuai/`)
- `stripPrefix` (default `true`) — `true` uses Caddy `handle_path` (prefix
  stripped before proxying); `false` uses `handle` (full URI passed through)
- `extraConfig` — extra Caddyfile lines inside the `reverse_proxy` block
- `extraLocations` — extra `handle` blocks for SPA assets/API at
  root-relative paths; **order matters, most specific paths first** (options.nix:58-68)
- `trustProxy` (`null` | `"express"` | `"uvicorn"`) — declares the backend
  proxy-trust mechanism so the module injects the matching env (options.nix:70-86)

### Caddyfile emission

`modules/nixos/proxy/config.nix` generates the Caddyfile:

- Site block: `http://:${port} { bind <listenAddresses> ... }` — the `http://`
  prefix disables automatic TLS; Tailscale handles HTTPS at the edge
  (config.nix:45-47). The site uses `:port` as the catch-all address because
  Tailscale serve preserves the original Host header.
- Each upstream becomes `${directive} ${path}* { reverse_proxy host:port ... }`
  via `handleBlock` (config.nix:15-25), `handle_path` when `stripPrefix`,
  `handle` otherwise.
- Dashboard opencode/ensemble API handles are emitted as
  `handle_path ${apiPath}/*` (config.nix:55-67).
- The dashboard itself is `handle /index.html` + `handle { root * ${dashboardDir}; file_server }` (config.nix:73-82).
- `services.nix` wires the systemd units: caddy `EnvironmentFile`,
  `metrics-collect` timer, and the `tailscale-serve` oneshot unit that runs
  `tailscale serve --bg --https ${httpsPort} http://<firstListenAddr>:<port>`
  (services.nix:132-146).
- `dashboard.nix` builds the static HTML page; `cfg.dashboard.opencode` /
  `cfg.dashboard.ensemble` entries render service cards and are populated by
  the opencode-web module (`my.services.opencodeWeb`).

## GOTCHAS — read before changing networking

### Tailscale

> **525: `tailscale-manager` fails on first deploy because Terraform isn't initialized**
> Fix: The local `modules/nixos/tailscale/config.nix` adds `preStart = "${config.services.tailscale-manager.package}/bin/tailscale-manager init"` which injects an `ExecStartPre` entry that runs init before apply. This is merged with the upstream's existing `ExecStartPre` entries via NixOS's `unitOption` merge (lists are concatenated). On an already-broken system, also run `sudo tailscale-manager init` manually in `/var/lib/tailscale-manager/` to initialize the existing state dir.

> **531: `tailscale-manager` structured policy serialization includes empty nested fields, breaking Tailscale API**
> Cause: The upstream v0.3.2 `policyToJSON` uses shallow `lib.filterAttrs` that only cleans top-level keys. Empty submodule defaults like `autoApprovers = { appConnectors = []; exitNode = []; routes = {}; }` pass through, and Tailscale's API rejects `appConnectors` when it's not yet supported or recognized.
> **Update (2026-08-03):** the module has since re-migrated to the structured `policy.*` options — `modules/nixos/tailscale/manager.nix:16-43` now builds the upstream `services.tailscale-manager.policy` attrset directly from `cfg.policy.*`, including `appConnectors` (manager.nix:35) and `autoApprovers` (manager.nix:36), merged with `cfg.policy.extraConfig`. The raw `acl.policy` string workaround was removed and is now historical.

### Caddy / proxy

> **34: Caddy env placeholders are `{$VAR}`, not shell-style `${VAR}`**
> Fix: emit `{` *before* the escaped `$`: `"header_up Authorization \"{\$${i.apiAuthEnv}}\""` → `{$OPENCODE_WEB_BASIC_AUTH}`. Verify by `caddy adapt` with the env var exported and grepping the adapted JSON. Related: `header_up` is a `reverse_proxy` *sub-directive* — it must be nested inside `reverse_proxy host:port { … }`, not a sibling.

> **118: Nginx location collision between proxy services** — historical. The current proxy module uses **Caddy**, which uses first-match `handle`/`handle_path` semantics rather than nginx's regex-vs-prefix precedence. The `^~` modifier is nginx-specific and not needed in the current architecture. The `extraLocations` pattern was carried forward.

> **141: Dashboard/proxy upstream host mismatch — Caddy `reverse_proxy` points at wrong IP**
> Cause: The service binds to a non-loopback IP (e.g. Tailscale IP via `autoBindTailscaleIp`) but Caddy's upstream `host` defaults to `127.0.0.1`. The module registers the upstream with only `port` and `path`, leaving `host` at the default `"127.0.0.1"`. When the service binds elsewhere, Caddy can't connect. Fix: set `host` on the upstream registration to the actual bind address (the proxy module emits an eval-time warning when suwayomi has `autoBindTailscaleIp` enabled but host is still `127.0.0.1`).

> **154: Nix eval shows correct config but deployed Caddyfile is stale — git push + redeploy required**
> Fix: `git add -A && git commit -m "..." && git push` then `ssh server.tail685690.ts.net "cd ~/nixos-config && git pull && nix run .#activate"`.

> **328: Express/FastAPI backends reject Caddy `X-Forwarded-For` — add `trustProxy` on the upstream registration**
> Cause: Caddy's `reverse_proxy` always sets `X-Forwarded-For`, `X-Forwarded-Proto`, and `X-Forwarded-Host`. Express's `app.set('trust proxy', ...)` defaults to `false`, and uvicorn's `--forwarded-allow-ips` defaults to `127.0.0.1`.
> Fix: Set `trustProxy` on the upstream registration: `"express"` — the service needs `TRUST_PROXY=1` in its env; `"uvicorn"` — the service needs `FORWARDED_ALLOW_IPS=*` in its env.

## Verification

- `nix eval .#nixosConfigurations.server.config.my.services.tailscale.manager.policy --json` — inspect evaluated policy before deploying.
- `sudo tailscale-manager status --json` — confirm manager state (via the `tailscale-manager` tool).
- `caddy adapt` with the env var exported, then grep the adapted JSON — confirm Caddy env placeholders resolved correctly (GOTCHAS 34).
- `cat /etc/caddy/caddy_config | grep reverse_proxy` on the target host — confirm what Caddy is actually proxying (GOTCHAS 141).
