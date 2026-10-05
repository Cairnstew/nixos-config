# Project Zomboid Server

Thin wrapper around the upstream
[`nixos-projectzomboid-servers`](https://github.com/Cairnstew/nixos-projectzomboid-servers)
flake input (pinned in `flake.lock`), which manages declarative
[Project Zomboid](https://projectzomboid.com) dedicated servers: systemd units,
the shared SteamCMD install (app **380870**), console sockets, the `.ini` and
`SandboxVars.lua`, spawn files, firewall and cgroup caps.

> **Options live under `services.project-zomboid-servers.*`, not `my.*`.**
> Everything substantive is upstream, so re-exporting the option surface here
> would only create a second source of truth to drift on `nix flake update`.
> **The upstream
> [`docs/options.md`](https://github.com/Cairnstew/nixos-projectzomboid-servers/blob/master/docs/options.md)
> is the option reference** — and its CI fails if it ever falls behind the
> module, so it is always complete. Do not mirror it into this README.

## What stays in this repo

| File | What it does |
| --- | --- |
| `default.nix` | Import manifest: the upstream module + `config.nix`, `tests.nix`, `servers` |
| `config.nix` | Host-local wiring (below) |
| `tests.nix` | This config's assertions + a smoke-test oneshot |
| `servers/<name>.nix` | This repo's server definitions |
| `options.nix` | Intentionally empty — no `my.*` options are declared |

`config.nix` carries only what is about *this* config rather than about Project
Zomboid:

- **`dataDir = "/mnt/data/project-zomboid"`** (`mkDefault`) — the large SATA
  data disk. Upstream's `/var/lib` default lands on the NVMe root here, and PZ
  saves grow without bound.
- **`modpacks` = the upstream catalogue** (`mkDefault`) — plain data from the
  flake output, so packs stay versioned with the code that understands them.
  Currently `vanilla-plus` and `survival-hard`.
- **Group membership** — `seanc` is added to the PZ group so it can read the
  data dir and attach to console sockets. Upstream creates the group but does
  not populate it.
- **Reverse-proxy upstreams** — maps upstream's read-only `webConsoleUpstreams`
  into `my.services.proxy.upstreams`. Upstream cannot know about this repo's
  proxy module, so this half of the wiring is necessarily local.
- **Secret group handoff** — `age.secrets.pz-admin-password` is root-owned while
  PZ is dormant (agenix `chowns unconditionally at activation, so naming the PZ
  group in the manifest would break rebuilds on every host where PZ is off), and
  handed to the PZ group the moment `services.project-zomboid-servers.enable` is
  true.

## Enabling a server

Servers are declared disabled. Opt in from a host config or profile:

```nix
services.project-zomboid-servers = {
  enable = true;
  servers.knox.enable = true;
};
```

`services.project-zomboid-servers.enable` still has to be set — the module
imports into `nixosModules.common`, so it is present on every host but inert.

## Verifying

```bash
systemctl start project-zomboid-smoke-test   # reports the resolved layout, fetches nothing
nix run .#pz-modpack -- list                 # upstream CLI, no host needed
```

The smoke test prints each server's resolved ports, derived/pinned map, Workshop
items, `.ini` path and unit name, using upstream's own `resolveServer` so it
cannot disagree with what the module will actually render.

Upstream's own suite (11 checks, including in-Nix assertions over the generated
units) runs against the input:

```bash
nix flake check path:/home/seanc/Projects/nixos-projectzomboid-servers
```

## Implementation changes belong upstream

This module declares `upstream = { mode = "wrapped"; space =
"project-zomboid-servers"; }` in `meta.nix`. Module behaviour, the modpack
catalogue and the CLI apps are **not** edited here. Only `dataDir`, the secret
group handoff, proxy wiring, `tests.nix` and `servers/` are local. See
`modules/AGENT.md` §4.2.

**Before you open any implementation file, decide which side you are on:**

| You want to change | Do it in |
| --- | --- |
| A module option, the systemd units, the `.ini`/lua renderers, map derivation, a pack in the catalogue, a CLI app, the upstream module's own docs or `.opencode/` tooling | **upstream**, via the space below |
| `dataDir`, the `pz-admin-password` secret wiring, `my.services.proxy.upstreams`, this repo's assertions, `servers/<name>.nix`, `meta.nix`/`options.nix`/`tests.nix`/`README.md` here | **this repo** |

If you are not sure, the option's definition settles it: anything declared in
upstream's `modules/options.nix` is upstream's. This module declares **no**
options of its own (`options.nix` is intentionally empty), so there is no
ambiguous middle ground.

### Spawning an agent to make the upstream change

**Load the `opencode-ensemble` skill first** — it is the only place
`team_spawn` and Agent Spaces are documented, and `AGENTS.md` §5.3 requires it
before touching a module whose `meta.nix` names a space.

```bash
team_create name="pz-upstream"            # once per piece of work
team_spawn  name="pz-fix" \
            space="project-zomboid-servers" \
            worktree=false \
            prompt="<the concrete upstream change>"
```

Non-negotiable details:

- **`space="project-zomboid-servers"`** — the space name registered in
  `modules/nixos/homeManager/config.nix`. It clones
  `/home/seanc/Projects/nixos-projectzomboid-servers` (pinned by
  `flakeInput = "project-zomboid-servers"`), so the teammate gets its own git
  history and its own remote, and its work never lands on this repo's branch.
- **`worktree=false` is mandatory.** Spaces and worktrees are mutually
  exclusive; passing `true` errors.
- One coherent upstream change per teammate. The upstream repo is small; two
  teammates editing `modules/options.nix` will collide.

The teammate commits and pushes to `master`. Because the space sets
`autoUpdateFlakeInput = true`, a clean shutdown reports the new SHA — then
re-pin here:

```bash
nix flake update project-zomboid-servers
```

`nix flake update` on a **private** input needs a token:

```bash
nix flake update project-zomboid-servers \
  --option access-tokens "github.com=$GITHUB_TOKEN"
```

Then re-verify — `nix flake check path:/home/seanc/Projects/nixos-projectzomboid-servers`
runs the upstream suite, and a host `nix eval` proves this repo still merges.

**If the space is unavailable, work in the clone directly** rather than editing
here: `cd /home/seanc/Projects/nixos-projectzomboid-servers`, commit, push, then
re-pin. `team_spawn` fails with `Unknown agent space` until the config carrying
the space has been **activated and opencode restarted** — the plugin reads
`~/.config/opencode/ensemble.json` once at process start, and that path is a
symlink into `/nix/store` that only a Home Manager activation can repoint. That
is not a reason to fall back to editing this repo.

## OpenCode tooling

The `pz-modpack` skill and `pz-modpack-status` tool that used to live here now
live in the upstream repo's own `.opencode/`, alongside the knowledge they encode
about this project. They are not installed into `~/.config/opencode` by this
config.