# MCP (Model Context Protocol) Setup Guide

This document explains how MCP servers are configured in this project and how to add project-specific MCP servers.

## What is MCP?

MCP (Model Context Protocol) allows AI assistants like OpenCode to connect to external tools. Think of it as a standardized way for AI to use tools - similar to how LSP works for editors.

## Current MCP Server: mcp-nixos

The `mcp-nixos` server provides Nix/NixOS-specific tools:

| Tool | Description |
|------|-------------|
| `nix_eval` | Evaluate Nix expressions |
| `nix_build` | Build Nix derivations |
| `nix_flake_check` | Run `nix flake check` |
| `nix_flake_show` | Show flake outputs |
| `nix_search` | Search nixpkgs |
| `nixos_config_info` | List NixOS configurations |
| `nixos_option` | Get NixOS option docs |

## How MCP is Configured

### Global Configuration (All Projects)

The MCP server is configured in your home-manager opencode settings:

```nix
# modules/nixos/homeManager/default.nix
my.programs.opencode = {
  enable = true;
  enableMcpIntegration = true;  # Enable MCP support
  settings.mcp = {
    nixos = {
      enabled = true;
      type = "local";
      command = [ "nix" "run" "${flake.inputs.self}#mcp-nixos" ];
    };
  };
};
```

### How It Works

1. **MCP Config Location**: `~/.config/opencode/config.json` (managed by home-manager)
2. **MCP Server Binary**: Built from `packages/mcp-nixos/`
3. **Protocol**: MCP uses JSON-RPC over stdio with length-prefixed messages

## Adding Project-Specific MCP Servers

### Method 1: Per-Project via opencode settings (Recommended)

You can add project-specific MCP servers by creating a local opencode config file. However, since the configuration is managed by home-manager, the better approach is:

**Option A: Use the `.opencode` directory in your project**

Create `.opencode/mcp.json` in your project root:

```json
{
  "mcpServers": {
    "my-project-server": {
      "command": "nix",
      "args": ["run", "./#mcp-myserver"]
    }
  }
}
```

But opencode doesn't automatically read this file. Instead, you need to:

**Option B: Set via environment variable or command line**

Unfortunately, opencode doesn't currently support project-level MCP config files directly. The MCP config must be in the main config file.

### Method 2: Dynamic MCP Server Selection (Best Practice)

Since opencode doesn't have native project-level MCP config, you can work around this by:

1. **Creating a wrapper script** that sets up project-specific MCP:

```bash
#!/bin/bash
# .opencode/run.sh - Run opencode with project MCP

PROJECT_MCP='{"mcpServers":{"my-server":{"command":"nix","args":["run","./#mcp-project"]}}}'

# Merge with existing config or use standalone
opencode "$@"
```

2. **Using direnv to set OpenCode config per project**:

```bash
# .envrc
export OPENCODE_CONFIG=$(pwd)/.opencode/config.json
```

But opencode doesn't support `OPENCODE_CONFIG` env var. Let me check what it does support.

### Method 3: Custom opencode Wrapper (Working Solution)

Create a project-specific opencode launcher:

```bash
#!/usr/bin/env bash
# .opencode/opencode-project

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Generate project-specific MCP config
mkdir -p "$PROJECT_ROOT/.opencode"
cat > "$PROJECT_ROOT/.opencode/mcp-local.json" \&lt;&lt; 'EOF'
{
  "mcpServers": {
    "nixos": {
      "enabled": true,
      "type": "local",
      "command": ["nix", "run", "./#mcp-nixos"]
    },
    "my-project-tool": {
      "enabled": true,
      "type": "local",
      "command": ["./scripts/my-mcp-server.sh"]
    }
  }
}
EOF

# Run opencode with the project MCP config
# Note: This requires opencode to support config file override
opencode "$@"
```

### Method 4: The Simplest Working Approach

Since opencode reads MCP from its config file, and that file is managed by home-manager, the practical approach is:

**Add all MCP servers you use to your global opencode config, and enable/disable them per-project via the `enabled` flag:**

```nix
# In modules/nixos/homeManager/default.nix
my.programs.opencode = {
  enable = true;
  enableMcpIntegration = true;
  settings.mcp = {
    # Always available
    nixos = {
      enabled = true;
      type = "local";
      command = [ "nix" "run" "${flake.inputs.self}#mcp-nixos" ];
    };
    
    # Project-specific servers (controlled via settings)
    filesystem = {
      enabled = false;  # Disabled by default, enable per-project
      type = "local";
      command = [ "npx" "-y" "@modelcontextprotocol/server-filesystem" "/home/seanc" ];
    };
    
    git = {
      enabled = false;
      type = "local";
      command = [ "npx" "-y" "@modelcontextprotocol/server-git" ];
    };
  };
};
```

Then in a specific project, you can temporarily enable servers by editing the config or using the `opencode` CLI:

```bash
# List MCP servers
opencode mcp list

# Add a server temporarily
opencode mcp add --name filesystem --command "npx" --args "-y" "@modelcontextprotocol/server-filesystem" "."
```

## Creating Custom MCP Servers

### Step 1: Create the Server Package

Create `packages/mcp-myserver/default.nix`:

```nix
{ lib, python3, stdenv, makeWrapper }:

stdenv.mkDerivation {
  pname = "mcp-myserver";
  version = "0.1.0";

  src = ./.;

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    mkdir -p $out/bin $out/libexec
    cp myserver.py $out/libexec/
    makeWrapper ${python3}/bin/python $out/bin/mcp-myserver \
      --add-flags "$out/libexec/myserver.py"
  '';

  meta = {
    description = "My custom MCP server";
  };
}
```

### Step 2: Add to Overlays

Edit `overlays/default.nix`:

```nix
mcp-myserver = self.callPackage "${packages}/mcp-myserver" { };
```

### Step 3: Add to opencode Config

Edit `modules/nixos/homeManager/default.nix`:

```nix
my.programs.opencode.settings.mcp.myserver = {
  enabled = true;
  type = "local";
  command = [ "nix" "run" "${flake.inputs.self}#mcp-myserver" ];
};
```

### Step 4: Rebuild

```bash
nix run .#activate
```

## Testing MCP Servers

### Test the server directly:

```bash
# Run the server
nix run .#mcp-nixos

# Send a test message
echo 'Content-Length: 38

{"jsonrpc":"2.0","method":"tools/list","id":1}' | nix run .#mcp-nixos
```

### Check opencode MCP integration:

```bash
# List configured MCP servers
opencode mcp list

# Test a specific server
opencode mcp debug nixos
```

## MCP Protocol Reference

MCP uses JSON-RPC 2.0 over stdio with length-prefixed headers:

```
Content-Length: 123\r\n
\r\n
{"jsonrpc":"2.0","method":"tools/list","id":1}
```

### Required Methods

1. **initialize** - Server capabilities
2. **tools/list** - List available tools  
3. **tools/call** - Execute a tool

### Tool Definition

```json
{
  "name": "my_tool",
  "description": "What this tool does",
  "inputSchema": {
    "type": "object",
    "properties": {
      "param1": { "type": "string" }
    },
    "required": ["param1"]
  }
}
```

## Troubleshooting

### MCP Server not appearing

1. Check opencode config: `cat ~/.config/opencode/config.json | jq .mcp`
2. Verify server binary exists: `which mcp-nixos` or `nix run .#mcp-nixos -- --help`
3. Test server manually: `echo '{"jsonrpc":"2.0","method":"tools/list","id":1}' | nix run .#mcp-nixos`

### Server crashes or timeouts

1. Check logs: `opencode debug`
2. Test with verbose output: `opencode mcp debug nixos`
3. Verify dependencies are available in the nix shell

### Configuration not updating

1. Rebuild home-manager: `nix run .#activate`
2. Check the generated config: `cat ~/.config/opencode/config.json`
3. Restart opencode if running in server mode

## Resources

- [MCP Specification](https://modelcontextprotocol.io/)
- [OpenCode Documentation](https://opencode.ai/docs)
- [Home-Manager MCP Module](https://github.com/nix-community/home-manager/blob/master/modules/programs/mcp.nix)
- [Example MCP Servers](https://github.com/modelcontextprotocol/servers)
