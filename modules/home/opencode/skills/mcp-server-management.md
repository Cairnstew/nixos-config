---
name: mcp-server-management
description: "Use when adding or managing an MCP server in this opencode setup — servers are declared under my.programs.opencode.mcp and rendered into ~/.config/opencode/opencode.json at activation time."
---

# MCP Server Management

> Skill for adding and managing MCP (Model Context Protocol) servers in this opencode configuration

## Overview

MCP servers extend opencode with external tools (APIs, databases, services).
Servers are configured declaratively under `my.programs.opencode.mcp` and
rendered into `~/.config/opencode/opencode.json` at activation time.

## Architecture

```
modules/home/opencode/
├── config.nix       # MCP server definitions (my.programs.opencode.mcp.*)
├── options.nix      # Option declarations (mcp = mkOption { ... })
└── providers.nix    # Provider-specific MCP wiring (if any)

modules/nixos/secrets/
├── secrets-manifest.json  # Agenix secret declarations (for API keys)
└── <name>.age             # Encrypted secret blobs
```

## MCP Server Configuration Format

Each server is an attrset under `my.programs.opencode.mcp.<name>`:

```nix
my.programs.opencode.mcp.<name> = {
  enabled = true;                    # Boolean to activate
  type = "local";                    # "local" (stdio) or "remote" (SSE/HTTP)
  command = [ "npx" "-y" "some-mcp" ];  # Command + args (list of strings)
  timeout = 120000;                  # Optional: ms (default 5000)
  environment = {                    # Optional: env vars
    API_KEY = "{file:/path/to/key}";
  };
};
```

## Adding an MCP Server (No API Key Required)

Simplest case — server needs no authentication:

### 1. Add to `modules/home/opencode/config.nix`

Find the `mcp` block inside `my.programs.opencode` (around line 335):

```nix
mcp.nix-graph = {
  enabled = true;
  type = "local";
  command = [
    "${nixGraphPython}/bin/python3"
    "${../../../tools/nix-graph/mcp_server.py}"
    "--graph"
    "${../../../tools/nix-graph/graph.json}"
  ];
  timeout = 120000;
};
```

Add your server alongside existing ones:

```nix
mcp.my-server = {
  enabled = true;
  type = "local";
  command = [ "npx" "-y" "my-mcp-package" ];
  timeout = 120000;
};
```

### 2. Common command patterns

| Source | Command |
|--------|---------|
| npm/npx | `[ "npx" "-y" "package-name" ]` |
| uvx (Python) | `[ "uvx" "package-name" ]` |
| uvx (from) | `[ "uvx" "--from" "package-name" "server-name" ]` |
| local binary | `[ "${pkgs.my-package}/bin/my-server" ]` |
| python script | `[ "${pythonEnv}/bin/python3" "./path/to/server.py" ]` |
| go binary | `[ "terraform-mcp-server" "stdio" ]` |

### 3. Apply

```bash
nix run   # or nixos-rebuild switch
```

## Adding an MCP Server With an API Key (Agenix)

When the server needs a secret (API key, token, etc.):

### 1. Declare the secret in `modules/nixos/secrets/secrets-manifest.json`

Insert alphabetically among existing entries:

```json
{
  "name": "my-service-api-key",
  "scope": "main",
  "hosts": null,
  "owner": "seanc",
  "group": "users",
  "mode": "0400"
}
```

**Field reference:**

| Field | Value | Notes |
|-------|-------|-------|
| `name` | kebab-case secret name | Must match `.age` filename (without extension) |
| `scope` | `"main"` | Usually `"main"` for user secrets |
| `hosts` | `null` | `null` = available on all hosts |
| `owner` | `"seanc"` or `"root"` | File owner after decryption |
| `group` | `"users"` or `"root"` | File group after decryption |
| `mode` | `"0400"` | Read-only for owner |

### 2. Add the MCP server to `modules/home/opencode/config.nix`

Use `lib.mkIf` to make the server conditional on the secret existing:

```nix
mcp.my-service = lib.mkIf (config.age.secrets ? "my-service-api-key") {
  enabled = true;
  type = "local";
  command = [ "npx" "-y" "my-service-mcp" ];
  environment = {
    MY_SERVICE_API_KEY = "{file:${config.age.secrets.my-service-api-key.path}}";
  };
  timeout = 120000;
};
```

**Key pattern:** `config.age.secrets ? "secret-name"` returns `true` if the
secret is declared in the manifest. This prevents build failures when the
secret hasn't been created yet.

### 3. Create the encrypted secret

```bash
nix develop .#secrets    # enter secrets shell
agenix-manager new       # TUI to create the secret
```

Or manually:

```bash
agenix -e modules/nixos/secrets/my-service-api-key.age \
  -r /etc/agenix/secrets.nix
```

### 4. Apply

```bash
nix run
```

## Existing MCP Servers

| Server | Purpose | API Key? |
|--------|---------|----------|
| `nix-graph` | Static analysis of NixOS config graph (modules, options, imports) | No |
| `memory` | Knowledge graph for persistent cross-session facts | No |
| `github` | GitHub official: repos, file tree, issues, PRs, actions | Yes (`github-token`) |
| `pdf-mcp` | PDF text extraction, search, and structural analysis | No |
| `terraform` | Terraform/HCP provider + module registry | No |
| `ieee` | IEEE Xplore academic paper search | Yes (`ieee-api-key`) |
| `steam` | Steam game library management | Optional (`steam-api-key`) |
| `apify` | Apify hosted actors — scoped to the Wattpad Story Scraper | OAuth (no token in config) |

## Common Patterns

### Using `{file:...}` substitution

opencode replaces `{file:/path/to/file}` with the file contents at runtime:

```nix
environment = {
  API_KEY = "{file:${config.age.secrets.my-key.path}}";
};
```

### Persisting facts to the memory graph

Use `memory_create_entities` / `memory_add_observations` to store durable facts
(architecture decisions, module ownership, verified gotchas) that future sessions
can query with `memory_search_nodes`:

```
memory_create_entities([{
  "name": "module:tailscale",
  "entityType": "module",
  "observations": ["Owned by seanc", "Depends on common.nix", "Has manager.nix for ACL policy"]
}])
```

Query later: `memory_search_nodes("tailscale")` → returns entities + relations.

### Timeout guidance

| Server type | Recommended timeout |
|-------------|---------------------|
| Local (fast) | `5000` (default) |
| Local (npx/npm) | `120000` (first run downloads) |
| Remote (SSE) | `30000` |
| Heavy compute | `300000` |

### Disabling a server

Set `enabled = false` or wrap in `mkIf false`:

```nix
mcp.my-server = {
  enabled = false;  # still defined but won't start
  # ...
};
```

## Gotchas

1. **First `npx` run is slow** — npm downloads the package. Use `timeout = 120000`
   for npx-based servers.

2. **`lib.mkIf` is required for secret-dependent servers** — without it, builds
   fail when the `.age` file doesn't exist yet.

3. **Secrets must be alphabetically ordered** in `secrets-manifest.json` — the
   manifest is validated; out-of-order entries cause warnings.

4. **`{file:...}` is opencode syntax, not Nix** — the string is passed literally
   to opencode which does the substitution at runtime.

5. **`type = "local"` means stdio** — the server communicates via stdin/stdout.
   Use `"remote"` for SSE/HTTP endpoints with a `url` field instead of `command`.

6. **Environment variables are strings** — even boolean-looking values must be
   strings: `ENABLED = "true"` not `ENABLED = true`.

## Troubleshooting

### Server won't start

1. Check if the command exists: `which npx` / `which uvx`
2. Test manually: `npx -y my-mcp-package` (should start stdio server)
3. Check opencode logs: `~/.local/share/opencode/` or `opencode --debug`

### Secret not found

1. Verify manifest entry: `jq '.secrets[] | select(.name == "my-key")' modules/nixos/secrets/secrets-manifest.json`
2. Verify `.age` file exists: `ls modules/nixos/secrets/my-key.age`
3. Rebuild: `nix run`

### MCP server tools not appearing

1. Ensure `enabled = true`
2. Check opencode MCP status: in opencode, run `/mcp` or check settings
3. Verify command args are correct (list of strings, not a single string)

## RUN LOG

### 2026-10-11 — remote + OAuth MCP was under-documented; `apify` added as the worked example
- Lesson: every "Adding an MCP Server" path above is `type = "local"` (stdio) plus
  an optional agenix API key; `type = "remote"` appears only in Gotcha 5 ("use
  `url` instead of `command`") with no worked example. Adding a hosted MCP
  (https://apify.com/easyapi/wattpad-story-scraper) needed the opencode MCP docs
  to learn that remote servers take `url`/`headers`, and that opencode handles
  OAuth automatically (`opencode mcp auth <name>`, tokens in
  `~/.local/share/opencode/mcp-auth.json`) — so no secret or `.age` file is
  needed. This skill implied a secret was always required.
- Fix: added `mcp.apify` at `modules/home/opencode/config.nix:423` — a live
  remote example: `type = "remote"`, `url = "https://mcp.apify.com/?tools=…"`,
  `timeout = 30000`, no `environment`. Listed it in the table above. Verified the
  endpoint: `/` returns 401 unauthenticated and
  `/.well-known/oauth-authorization-server` returns the discovery document.
- Record-only: the actor page itself ships the exact MCP snippet
  (`{"type":"http","url":"https://mcp.apify.com/?tools=…"}`) — opencode's field
  is `"remote"` not `"http"`, so copy the URL, not the `type`.

### 2026-10-15 — project-level `.opencode/opencode.json` was undocumented
- Lesson: this skill only documents the nixos-config global path
  (`my.programs.opencode.mcp` → `~/.config/opencode/opencode.json`). Tasking
  "add this MCP to my project repo" (here: adding houdini-mcp to the `planet`
  repo and to `templates/houdini/`, neither of which has an `mcp` block) had no
  guidance to find — the project-local config lives in
  `<repo>/.opencode/opencode.json` and is picked up automatically by opencode
  when run from that directory. Different file, and different JSON shape: the
  key is `"mcp"`, `"command"` is a **list**, `"type"` is
  `"local"`/`"remote"`, and env vars go under `"env"` (not `"environment"` —
  that is the nixos-config `my.*` spelling). The repo already follows this
  pattern: `templates/godot/.opencode/opencode.json` is the worked example.
- Fix: added `.opencode/opencode.json` to `templates/houdini/` and to the
  `planet` repo with a `"houdini"` server (`nix run .#houdini-mcp`, stdio
  transport, `HOUDINI_HOST`/`HOUDINI_PORT`/`MCP_TRANSPORT`), and documented
  the MCP section in both READMEs. Verified both flakes still emit an app that
  starts a working stdio MCP server (`mcp.run(transport="stdio")` logs
  "Starting MCP server", no traceback).
- Record-only: `nix run .#app` was used so the config is self-contained in the
  project and needs no PATH assumption; the `timeout` field in the skill is a
  nixos-config-only option and is not valid in project `opencode.json`.

### 2026-10-15 — a `"command"` MCP must not assume `nix` is on PATH
- Lesson: an added MCP server passed every manual check and `nix flake check`,
  yet failed the moment opencode (re)started, logging
  `server unavailable key=houdini type=local status=failed`. Root cause: the
  opencode **web service is started by systemd** (`opencode-web-*.service`) and
  spawns MCP servers with its own restricted `PATH` — ripgrep, git, bash,
  coreutils, findutils, gnugrep, gnused, systemd, and **no `nix`**. So a
  project config command of `["nix", "run", ".#app"]` dies with
  `env: 'nix': No such file or directory`, exit 127, which opencode reports
  only as `status=failed` (no stderr detail). Manually re-running the same
  command in a shell always works, because a login/interactive shell has the
  full `PATH` — which is why the failure only appears after a restart and never
  in a hand-run reproduction.
- Fix: spell the interpreter out absolutely — `["/run/current-system/sw/bin/nix",
  "run", ".#houdini-mcp"]` — verified by re-running the config's exact
  `command` + `env` with the web server's real `PATH` copied straight out of
  `/proc/<service-pid>/environ` (`env PATH="$SRVPATH" … `), which reproduces
  exit 127 for the bare form and exit 0 for the absolute one.
- How to diagnose this in general: `tr '\0' '\n' < /proc/$(pgrep -f 'opencode.*web')/environ | grep ^PATH=`
  gives the exact PATH the MCP children inherit; compare it against the
  server's absolute command. Also confirm **stdout stays empty** — any stray
  stdout byte breaks the stdio JSON-RPC framing (`nix run` chatter goes to
  stderr, so a 0-byte stdout is the success signal).
- Record-only: this is why every *global* server in this repo's `mcp.*` blocks
  already uses absolute `/nix/store/...` paths rather than bare `npx`/`nix` —
  those are generated at activation time with no `PATH` dependency at all. The
  project-level `.opencode/opencode.json` route is the one place the pattern
  was missing.

### 2026-10-15 — a `nix run .#app` MCP ref needs an *absolute* flake path
- Lesson: after fixing the `PATH` problem above, the same server **still**
  failed with the identical `server unavailable … status=failed`. Two more
  traps, both invisible to a hand-run reproduction:
  1. **cwd, not just PATH.** The opencode web daemon spawns MCP children from
     its *own* cwd (its environ shows `PWD=/home/seanc/nixos-config`), never
     from the project directory — so a bare `.#houdini-mcp` ref resolves
     against the wrong directory and dies with
     `error: could not find a flake.nix file`. Reproducing with the project as
     cwd (the obvious thing to do) hides this completely.
  2. **"It started" is not "it works".** A stdio server starts, sees stdin at
     EOF, and exits 0 — so `exit 0` and a clean log look like success while
     opencode reports failure. `status=failed` also carries no stderr detail,
     so the log tells you nothing.
- Fix: reference the flake by absolute path —
  `["/run/current-system/sw/bin/nix", "run", "/abs/project#houdini-mcp"]` —
  verified to work with cwd set to the *daemon's* cwd. For the `templates/houdini/`
  template the scaffolded path is unknowable at commit time, so its flake's
  shellHook regenerates `.opencode/opencode.json` on every `nix develop`
  (idempotently, via `cmp` + atomic `mv`, resolving the root from
  `git rev-parse --show-toplevel` like `mkApp` does) — the same pattern it
  already uses for `pyrightconfig.json`. Do **not** bake in a build-time
  `self.outPath`: it lands in `/nix/store/*-source`, is not a GC root, and
  freezes the app at the revision current when the shell opened.
- How to actually verify an MCP server: send a real JSON-RPC `initialize`
  + `notifications/initialized` + `tools/list` over a pipe and assert you get
  a tool count back. Run it with the child's `PATH` copied from
  `/proc/<daemon-PID>/environ` **and** its cwd set to the daemon's cwd. A
  `tools=43` response is the success signal; "the banner printed" is not.
- Record-only: `nix flake check` on this repo currently fails with
  `path '…-skills' is not valid` under `flake output 'checks'`. This is
  pre-existing — reproduced with all local changes stashed — and is unrelated
  to any `.opencode`/MCP work.

### 2026-10-15 — `"env"` is not the opencode MCP env key; it is `"environment"`
- Lesson: the RUN LOG entry above ("env vars go under `"env"` (not
  `"environment"` — that is the nixos-config `my.*` spelling)") is **wrong**, and
  it is the root cause of the houdini MCP failing with
  `server unavailable key=houdini type=local status=failed`. opencode's MCP
  client silently **ignores unknown keys** (`McpLocalConfig` has
  `additionalProperties: false`), so `"env": {...}` is dropped without a warning.
  The server then falls back to its own default — `MCP_TRANSPORT` unset means
  **http** on :3055, so the child never speaks JSON-RPC on stdio and opencode
  kills it with `Operation timed out after 30000ms`.
- Evidence (measured this session, not inferred): `opencode mcp list` reported
  the 30 s timeout; wrapping the configured `command` in a stdin/stdout tee
  showed the banner `houdini-mcp: transport=http port=3055`, i.e. the env block
  never landed; renaming `env` → `environment` flipped it to
  `transport=stdio` and the same command reported `✓ houdini connected`. The
  `templates/godot/.opencode/opencode.json` "worked example" cited above uses
  `"environment"` — it was read past, not followed.
- The correct key is **`environment`** (same spelling as the nixos-config
  `my.*` option, and the only one that works in either file). Valid
  `McpLocalConfig` keys: `type`, `command`, `cwd`, `environment`, `enabled`,
  `timeout` — verify against the live schema `curl -s https://opencode.ai/config.json`
  rather than trusting this file. The `timeout` field is **not** a
  nixos-config-only option as claimed above: it is a valid local-MCP field
  ("Timeout in ms for MCP server requests"), so it *is* honoured in a project
  `opencode.json`.
- How to diagnose this in general: `opencode mcp list <name>`-style status
  output distinguishes the two failure modes — `Operation timed out after
  30000ms` means the child started but never spoke JSON-RPC (wrong transport /
  wrong interpreter / a banner on stdout), while an immediate failure means the
  command itself could not run. Never trust a stderr banner: a stdio server that
  sees stdin at EOF exits 0 and looks healthy.
- Fix: renamed `env` → `environment` in `planet/.opencode/opencode.json`,
  in `templates/houdini/.opencode/opencode.json`, and in the
  `syncOpencodeConfig` shell hook of `templates/houdini/flake.nix` that
  regenerates it on every `nix develop` (all three had to change, or the hook
  would rewrite the two files back to the broken form).
- Record-only: the 30 s MCP connect timeout is fixed in opencode and is not
  configurable per server for the *connect* phase; `timeout` only scales the
  per-request timeout.
