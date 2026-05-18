# MCP (Model Context Protocol) Servers

This module provides MCP server integration for the nixos-config project.

## What is MCP?

MCP (Model Context Protocol) is a protocol that allows AI assistants to connect
to external tools and data sources. Think of it as a "LSP for AI" - it standardizes
how AI assistants discover and use tools.

## Available MCP Servers

### mcp-nixos

Provides tools for Nix/NixOS operations:

| Tool | Description |
|------|-------------|
| `nix_eval` | Evaluate Nix expressions |
| `nix_build` | Build Nix derivations |
| `nix_flake_check` | Run `nix flake check` |
| `nix_flake_show` | Show flake outputs |
| `nix_search` | Search nixpkgs |
| `nixos_config_info` | List available NixOS configurations |
| `nixos_option` | Get NixOS option documentation |

## Usage

### For OpenCode Users

Create `.opencode/mcp.json` in your project root:

```bash
# Generate the MCP config file for your project
nix build .#mcp-config --no-link --print-out-paths | xargs cat > .opencode/mcp.json
```

Or manually create `.opencode/mcp.json`:

```json
{
  "mcpServers": {
    "nixos": {
      "command": "nix",
      "args": ["run", "/path/to/nixos-config#mcp-nixos"]
    }
  }
}
```

Replace `/path/to/nixos-config` with the absolute path to your flake (e.g., `~/nixos-config` or `.` if running from the project directory).

### For Claude Desktop Users

Add to `~/.config/claude/mcp.json`:

```json
{
  "mcpServers": {
    "nixos": {
      "command": "nix",
      "args": ["run", "${HOME}/nixos-config#mcp-nixos"]
    }
  }
}
```

## Adding Custom MCP Servers

### Method 1: Simple Script (Recommended for quick tools)

1. Create a script in `packages/mcp-myserver/`:

```nix
# packages/mcp-myserver/default.nix
{ lib, python3, stdenv, makeWrapper }:

stdenv.mkDerivation {
  pname = "mcp-myserver";
  version = "0.1.0";

  src = ./.;

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    mkdir -p $out/bin
    cp myserver.py $out/libexec/
    makeWrapper ${python3}/bin/python $out/bin/mcp-myserver \
      --add-flags "$out/libexec/myserver.py"
  '';
}
```

2. Add to `overlays/default.nix`:

```nix
mcp-myserver = self.callPackage "${packages}/mcp-myserver" { };
```

3. Register in `modules/flake-parts/mcp-servers.nix`:

```nix
my.mcp.servers.myserver = {
  command = "nix";
  args = [ "run" ".#mcp-myserver" ];
  description = "My custom MCP server";
};
```

### Method 2: Full Package (Recommended for complex tools)

Follow the same structure as `packages/mcp-nixos/`:

```
packages/mcp-myserver/
├── default.nix      # Package definition
├── myserver.py      # Server implementation
└── README.md        # Documentation
```

### Method 3: External MCP Servers

To add an existing MCP server from nixpkgs or elsewhere:

```nix
# In modules/flake-parts/mcp-servers.nix
my.mcp.servers = {
  # External MCP server from nixpkgs
  filesystem = {
    command = "${pkgs.nodePackages.@anthropic-ai/mcp-server-filesystem}/bin/mcp-server-filesystem";
    args = [ "/home/user" ];
    description = "Filesystem access for AI";
  };

  # Docker MCP server
  docker = {
    command = "docker";
    args = [ "run", "-i", "--rm", "mcp/docker" ];
    description = "Docker management";
  };
};
```

## MCP Server Protocol

MCP servers communicate via stdio using JSON-RPC 2.0 messages with a length-prefixed header:

```
Content-Length: 123\r\n
\r\n
{"jsonrpc":"2.0",...}
```

### Required Methods

1. **initialize** - Server capabilities
2. **tools/list** - List available tools
3. **tools/call** - Execute a tool

### Tool Definition Schema

```json
{
  "name": "tool_name",
  "description": "What this tool does",
  "inputSchema": {
    "type": "object",
    "properties": {
      "param1": {
        "type": "string",
        "description": "Parameter description"
      }
    },
    "required": ["param1"]
  }
}
```

## Development Tips

### Testing Your MCP Server

```bash
# Run the server directly
nix run .#mcp-nixos

# Test with a simple JSON-RPC message
echo 'Content-Length: 38

{"jsonrpc":"2.0","method":"tools/list","id":1}' | nix run .#mcp-nixos
```

### Debugging

Add logging to your MCP server:

```python
import sys
import logging

logging.basicConfig(
    filename='/tmp/mcp-debug.log',
    level=logging.DEBUG
)

# Log all messages
logging.debug(f"Received: {msg}")
```

### Common Pitfalls

1. **Buffering**: Ensure stdout is flushed after each message
2. **Timeouts**: MCP clients may timeout after 30-60 seconds
3. **JSON encoding**: Always use proper JSON, no trailing commas
4. **Large outputs**: Split large outputs across multiple content items

## References

- [MCP Specification](https://modelcontextprotocol.io/)
- [MCP Python SDK](https://github.com/modelcontextprotocol/python-sdk)
- [MCP TypeScript SDK](https://github.com/modelcontextprotocol/typescript-sdk)
- [Example MCP Servers](https://github.com/modelcontextprotocol/servers)
