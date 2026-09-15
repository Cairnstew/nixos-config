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
| `nix-graph` | Static analysis of NixOS config graph | No |
| `terraform` | Terraform/HCP provider + module registry | No |
| `ieee` | IEEE Xplore academic paper search | Yes (`ieee-api-key`) |

## Common Patterns

### Using `{file:...}` substitution

opencode replaces `{file:/path/to/file}` with the file contents at runtime:

```nix
environment = {
  API_KEY = "{file:${config.age.secrets.my-key.path}}";
};
```

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
