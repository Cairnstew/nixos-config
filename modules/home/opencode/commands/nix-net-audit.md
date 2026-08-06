---
description: Read-only network/ACL/proxy audit — tailscale policy, Caddy upstreams, exposure gaps
---

You are a network/ACL/proxy auditor working inside the nixos-config repo.
This command is **read-only**. Never modify files.
**Never modify system state. Never run `nixos-rebuild` with any action
(switch/boot/test) — only grep, read, eval, and status queries.**

---

## AVAILABLE TOOLS

| Tool | Use here |
|------|----------|
| `tailscale-manager` | Live tailnet status as JSON (`sudo tailscale-manager status --json`). Read-only. |
| `nix-eval` | Evaluate `my.*` option values read-only (e.g. `my.services.proxy.upstreams`). |
| `nix-hosts` | List configured hosts, platforms, and enabled profiles. |
| `nix-graph_*` | Static graph: find where options are declared/defined, import dependents. |
| bash (read-only) | `grep`/`read`/`ls` only. No service mutations, no rebuilds, no writes. |

---

## START HERE — LOAD THE CONFIG MODEL FROM THE SKILL

Read the `network-security` skill first. It is the source of truth for the
config model this audit runs against — do **not** re-derive it from the code.

Skill locations:
- Installed: `~/.config/opencode/skills/network-security/SKILL.md`
- Repo source: `modules/home/opencode/skills/network-security.md`

Read whichever exists. Then run this audit *against* that model: every option
the skill describes must be checked for (a) declared in `options.nix`, (b)
actually defined in a host or module, (c) covered by tests. Cross-reference the
skill's sections by name rather than restating their prose. When you report,
cite the skill section each finding maps to.

Skill sections referenced (load their headings; this command covers the
inventory, not the model):
- `## Overview` — the two layers (Tailscale policy + Caddy proxy) and the `my.*` options they use.
- `## Tailscale ACL Model` — the `policy.*` sub-option table, ACL/grant/SSH shapes, and how `manager.nix` maps policy upstream.
- `## Reading / Modifying the Policy` — read-only `nix eval` audit pattern; the skill's grant + assertion-test snippet is the reference for M3 coverage checks.
- `## tailscale-manager Tool` — status-only tool; policy is changed via config+deploy, never the tool.
- `## Proxy Upstreams (Caddy)` — the `my.services.proxy.upstreams.*` registration model this audit inventories.
- `## Verification` — the eval/status/caddy-adapter/grep commands the audit should mirror.
- `## GOTCHAS` — read before reporting on networking; do not restate here.

---

## M1. Tailscale inventory (read-only)

Pull live status first, then the declared policy. Quote raw output.

```
tailscale-manager status   # requires sudo — status JSON: hosts, tags, serve/funnel
```

Policy source of truth:
!`grep -n "policy\." modules/nixos/tailscale/manager.nix`
!`grep -n "policy\s*=\|grants\|acls\|ssh\|autoApprovers\|tagOwners\|interNodePorts\|groups\|hosts\|ipsets\|postures\|nodeAttrs\|appConnectors\|derpMap\|tests\|sshTests" modules/nixos/tailscale/options.nix`

Where policy is actually defined (hosts/modules):
!`grep -rn "my.services.tailscale" configurations/ modules/nixos --include="*.nix" | grep -v "/tests.nix\|/options.nix"`

Then:
- List every active ACL rule (`policy.acls`), grant (`policy.grants` +
  auto-generated from `policy.interNodePorts`), SSH rule (`policy.ssh`), tag /
  tag-owner mapping (`policy.tags` / `policy.tagOwners`), and auto-approver
  (`policy.autoApprovers`).
- Note which host "owns" the policy (e.g. desktop manages ACL policy).
- **Coverage flag:** cross-reference the `policy.tests` / `policy.sshTests`
  assertions in `modules/nixos/tailscale/tests.nix` against the declared rules.
  List every rule that has **no** corresponding test.

Output format:
```
### Tailscale
live status: <quote tailscale-manager output>
tags: <list>
tag owners: <mapping>
acls: <list>
grants: <list> (incl. auto-generated interNodePorts)
ssh rules: <list>
autoApprovers: <list>
rules covered by tests: <list>
rules NOT covered by tests: <list>  ⚠️
```

---

## M2. Caddy / proxy inventory (read-only)

Options model:
!`grep -n "upstreams\|listenAddresses\|port\s*=\|tailscaleServe\|dashboard\|systemMetrics\|extraConfig" modules/nixos/proxy/options.nix`

Auto-registered upstreams — which service modules publish into the proxy:
!`grep -rn "my.services.proxy.upstreams" modules/nixos --include="*.nix" | grep -v "/tests.nix"`

Per-host proxy overrides:
!`grep -rn "my.services.proxy" configurations/nixos --include="*.nix"`

Caddyfile generation + tailscale serve wiring:
!`grep -n "handle_path\|handle\b\|reverse_proxy\|bind\|stripPrefix" modules/nixos/proxy/config.nix`
!`grep -n "tailscale serve\|httpsPort\|ExecStart\|ExecStop" modules/nixos/proxy/services.nix`

Then, for each registered upstream, read its service `config.nix` and report:
`port`, `path` (+ `stripPrefix` semantics: `handle_path` strips, `handle`
passes through), `extraLocations`, `trustProxy` mechanism. Summarise:
- The Caddy listen surface: `port`, `listenAddresses`, `bind`.
- Tailscale serve: `enable`, `httpsPort`, the `serve --bg --https :443 → http://<listenAddr>:<port>` mapping.
- Dashboard exposure: `dashboard.enable`, `title`, opencode instance count, ensemble card.

Output format:
```
### Caddy / proxy
caddy port: <p>  listenAddresses: <list>
tailscaleServe: <enable>  httpsPort: <p>
upstreams registered:
  - <name>: port=<p> path=<path> stripPrefix=<bool> extraLocations=<n> trustProxy=<mech>
dashboard: title=<t> opencode=<n instances> ensemble=<bool>
exposure surface: <tailnet URL(s)>
```

---

## M3. Exposure & coverage analysis

Cross-reference M1 and M2 against the skill's config model:

1. **Every exposed path/port must be reachable per the policy model.** Map each
   Caddy upstream and tailscale-serve port to the ACL/grant that permits it.
2. Flag: upstreams registered in Caddy but with no corresponding grant/ACL
   (or only a permissive default). Flag: grants/ports in policy that no Caddy
   listener actually binds.
3. Flag: `listenAddresses` vs `tailscaleServe` mismatch (serve target must be a
   bound listen address).
4. Flag: any policy field populated in a host/module but absent from
   `policy.tests` / `policy.sshTests` (uncovered policy is a drift risk).
5. Flag: `trustProxy` set on an upstream whose backend cannot enforce
   X-Forwarded-For trust.

---

## REPORT

Quote raw grep/eval output throughout. End with:

```
## AUDIT SUMMARY
### Exposure map
<host> → <port>/<path> → <who can reach it per policy>
### Policy gaps
- <rule without test>
### Proxy gaps
- <upstream without policy / bind vs grant mismatch / serve mismatch>
### Verdict
<OK or N findings, no changes made>
```

**Read-only note:** this audit made no system-state changes and ran no
`nixos-rebuild`. For remediation, propose changes and run the `nix-refine`
command instead.
