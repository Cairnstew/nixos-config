#!/usr/bin/env python3
"""
MCP (Model Context Protocol) Server for Nix/NixOS operations.

Provides tools for:
- Evaluating Nix expressions
- Building Nix packages
- Running flake checks
- Inspecting flake outputs
- Searching nixpkgs
"""

import json
import sys
import subprocess
import os
from pathlib import Path


def send_message(msg: dict):
    """Send a JSON-RPC message to stdout."""
    json_str = json.dumps(msg)
    sys.stdout.write(f"Content-Length: {len(json_str)}\r\n\r\n{json_str}")
    sys.stdout.flush()


def read_message():
    """Read a JSON-RPC message from stdin."""
    # Read headers
    headers = {}
    while True:
        line = sys.stdin.readline()
        if line == "\r\n":
            break
        if line == "":
            return None
        if ":" in line:
            key, value = line.split(":", 1)
            headers[key.strip()] = value.strip()
    
    # Read body
    if "Content-Length" not in headers:
        return None
    
    length = int(headers["Content-Length"])
    body = sys.stdin.read(length)
    return json.loads(body)


def run_nix_command(args: list, cwd: str = None, capture_stderr: bool = True) -> tuple:
    """Run a nix command and return (success, stdout, stderr)."""
    cmd = ["nix"] + args
    try:
        stderr_pipe = subprocess.PIPE if capture_stderr else None
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            cwd=cwd,
            timeout=300  # 5 minute timeout
        )
        return (
            result.returncode == 0,
            result.stdout,
            result.stderr if capture_stderr else ""
        )
    except subprocess.TimeoutExpired:
        return (False, "", "Command timed out after 5 minutes")
    except Exception as e:
        return (False, "", str(e))


# Tool definitions
TOOLS = [
    {
        "name": "nix_eval",
        "description": "Evaluate a Nix expression and return the result",
        "inputSchema": {
            "type": "object",
            "properties": {
                "expression": {
                    "type": "string",
                    "description": "Nix expression to evaluate"
                },
                "flake": {
                    "type": "string",
                    "description": "Optional flake path (e.g., ./. or /path/to/flake)"
                },
                "json": {
                    "type": "boolean",
                    "description": "Output as JSON",
                    "default": True
                }
            },
            "required": ["expression"]
        }
    },
    {
        "name": "nix_build",
        "description": "Build a Nix derivation or flake output",
        "inputSchema": {
            "type": "object",
            "properties": {
                "target": {
                    "type": "string",
                    "description": "Target to build (e.g., '.#mypackage' or '/nix/store/...')"
                },
                "flake": {
                    "type": "string",
                    "description": "Optional flake path",
                    "default": "."
                },
                "dry_run": {
                    "type": "boolean",
                    "description": "Dry run - don't actually build",
                    "default": False
                }
            },
            "required": ["target"]
        }
    },
    {
        "name": "nix_flake_check",
        "description": "Run 'nix flake check' to validate a flake",
        "inputSchema": {
            "type": "object",
            "properties": {
                "flake": {
                    "type": "string",
                    "description": "Path to the flake",
                    "default": "."
                },
                "no_build": {
                    "type": "boolean",
                    "description": "Check without building (faster)",
                    "default": True
                }
            }
        }
    },
    {
        "name": "nix_flake_show",
        "description": "Show flake outputs (nix flake show)",
        "inputSchema": {
            "type": "object",
            "properties": {
                "flake": {
                    "type": "string",
                    "description": "Path to the flake",
                    "default": "."
                }
            }
        }
    },
    {
        "name": "nix_search",
        "description": "Search for packages in nixpkgs",
        "inputSchema": {
            "type": "object",
            "properties": {
                "query": {
                    "type": "string",
                    "description": "Search query"
                },
                "channel": {
                    "type": "string",
                    "description": "Nix channel to search (default: nixpkgs)",
                    "default": "nixpkgs"
                }
            },
            "required": ["query"]
        }
    },
    {
        "name": "nixos_config_info",
        "description": "Get information about available NixOS configurations in this flake",
        "inputSchema": {
            "type": "object",
            "properties": {}
        }
    },
    {
        "name": "nixos_option",
        "description": "Get documentation for a NixOS option",
        "inputSchema": {
            "type": "object",
            "properties": {
                "option": {
                    "type": "string",
                    "description": "Option path (e.g., 'services.nginx.enable')"
                }
            },
            "required": ["option"]
        }
    }
]


def handle_nix_eval(params: dict) -> dict:
    """Handle nix_eval tool."""
    expr = params.get("expression", "")
    flake = params.get("flake")
    json_output = params.get("json", True)
    
    args = ["eval"]
    if json_output:
        args.append("--json")
    
    if flake:
        args.append(f"--flake")
        args.append(f"{flake}#{expr}" if expr else flake)
    else:
        args.append("--expr")
        args.append(expr)
    
    success, stdout, stderr = run_nix_command(args)
    
    if success:
        return {
            "content": [{"type": "text", "text": stdout or "(empty result)"}],
            "isError": False
        }
    else:
        return {
            "content": [{"type": "text", "text": f"Error: {stderr}"}],
            "isError": True
        }


def handle_nix_build(params: dict) -> dict:
    """Handle nix_build tool."""
    target = params.get("target", "")
    flake = params.get("flake", ".")
    dry_run = params.get("dry_run", False)
    
    args = ["build"]
    if dry_run:
        args.append("--dry-run")
    
    # Handle both flake and non-flake targets
    if target.startswith("#") or ":" in target:
        args.append(f"{flake}{target}" if target.startswith("#") else target)
    else:
        args.append(target)
    
    args.extend(["--no-link", "--print-out-paths"])
    
    success, stdout, stderr = run_nix_command(args)
    
    if success:
        return {
            "content": [{"type": "text", "text": stdout or "Build successful"}],
            "isError": False
        }
    else:
        return {
            "content": [{"type": "text", "text": f"Build failed:\n{stderr}"}],
            "isError": True
        }


def handle_nix_flake_check(params: dict) -> dict:
    """Handle nix_flake_check tool."""
    flake = params.get("flake", ".")
    no_build = params.get("no_build", True)
    
    args = ["flake", "check", flake]
    if no_build:
        args.append("--no-build")
    
    success, stdout, stderr = run_nix_command(args, capture_stderr=False)
    
    if success:
        return {
            "content": [{"type": "text", "text": "✓ Flake check passed"}],
            "isError": False
        }
    else:
        return {
            "content": [{"type": "text", "text": f"Flake check failed:\n{stderr}"}],
            "isError": True
        }


def handle_nix_flake_show(params: dict) -> dict:
    """Handle nix_flake_show tool."""
    flake = params.get("flake", ".")
    
    args = ["flake", "show", flake, "--json"]
    success, stdout, stderr = run_nix_command(args)
    
    if success:
        # Pretty print the JSON
        try:
            data = json.loads(stdout)
            formatted = json.dumps(data, indent=2)
            return {
                "content": [{"type": "text", "text": formatted}],
                "isError": False
            }
        except json.JSONDecodeError:
            return {
                "content": [{"type": "text", "text": stdout}],
                "isError": False
            }
    else:
        return {
            "content": [{"type": "text", "text": f"Error: {stderr}"}],
            "isError": True
        }


def handle_nix_search(params: dict) -> dict:
    """Handle nix_search tool."""
    query = params.get("query", "")
    channel = params.get("channel", "nixpkgs")
    
    args = ["search", channel, query, "--json"]
    success, stdout, stderr = run_nix_command(args)
    
    if success:
        try:
            data = json.loads(stdout)
            if not data:
                return {
                    "content": [{"type": "text", "text": f"No results found for '{query}'"}],
                    "isError": False
                }
            
            # Format results
            results = []
            for name, info in list(data.items())[:20]:  # Limit to 20 results
                desc = info.get("description", "No description")
                results.append(f"{name}: {desc}")
            
            return {
                "content": [{"type": "text", "text": "\n".join(results)}],
                "isError": False
            }
        except json.JSONDecodeError:
            return {
                "content": [{"type": "text", "text": stdout}],
                "isError": False
            }
    else:
        return {
            "content": [{"type": "text", "text": f"Search failed: {stderr}"}],
            "isError": True
        }


def handle_nixos_config_info(params: dict) -> dict:
    """Handle nixos_config_info tool."""
    # Try to find flake.nix in current or parent directories
    cwd = os.getcwd()
    flake_dir = None
    
    for path in [cwd] + list(Path(cwd).parents):
        if (path / "flake.nix").exists():
            flake_dir = str(path)
            break
    
    if not flake_dir:
        return {
            "content": [{"type": "text", "text": "No flake.nix found in current directory or parents"}],
            "isError": True
        }
    
    # Get nixosConfigurations
    args = ["eval", f"{flake_dir}#nixosConfigurations", "--json", "--apply", "builtins.attrNames"]
    success, stdout, stderr = run_nix_command(args)
    
    if success:
        try:
            configs = json.loads(stdout)
            if configs:
                return {
                    "content": [{"type": "text", "text": f"Available NixOS configurations:\n" + "\n".join(f"  - {c}" for c in configs)}],
                    "isError": False
                }
            else:
                return {
                    "content": [{"type": "text", "text": "No NixOS configurations found in this flake"}],
                    "isError": False
                }
        except json.JSONDecodeError:
            return {
                "content": [{"type": "text", "text": stdout}],
                "isError": False
            }
    else:
        return {
            "content": [{"type": "text", "text": f"Failed to get configurations: {stderr}"}],
            "isError": True
        }


def handle_nixos_option(params: dict) -> dict:
    """Handle nixos_option tool."""
    option = params.get("option", "")
    
    args = ["os", "option", "--json", option]
    success, stdout, stderr = run_nix_command(args)
    
    if success:
        try:
            data = json.loads(stdout)
            formatted = json.dumps(data, indent=2)
            return {
                "content": [{"type": "text", "text": formatted}],
                "isError": False
            }
        except json.JSONDecodeError:
            return {
                "content": [{"type": "text", "text": stdout}],
                "isError": False
            }
    else:
        return {
            "content": [{"type": "text", "text": f"Failed to get option: {stderr}"}],
            "isError": True
        }


def handle_tool_call(name: str, params: dict) -> dict:
    """Route tool calls to appropriate handlers."""
    handlers = {
        "nix_eval": handle_nix_eval,
        "nix_build": handle_nix_build,
        "nix_flake_check": handle_nix_flake_check,
        "nix_flake_show": handle_nix_flake_show,
        "nix_search": handle_nix_search,
        "nixos_config_info": handle_nixos_config_info,
        "nixos_option": handle_nixos_option,
    }
    
    handler = handlers.get(name)
    if handler:
        return handler(params)
    else:
        return {
            "content": [{"type": "text", "text": f"Unknown tool: {name}"}],
            "isError": True
        }


def main():
    """Main entry point - MCP protocol handler."""
    # Send initialization response
    init_response = {
        "jsonrpc": "2.0",
        "id": 1,
        "result": {
            "protocolVersion": "2024-11-05",
            "serverInfo": {
                "name": "mcp-nixos",
                "version": "0.1.0"
            },
            "capabilities": {
                "tools": {}
            }
        }
    }
    send_message(init_response)
    
    # Main loop
    while True:
        msg = read_message()
        if msg is None:
            break
        
        method = msg.get("method", "")
        msg_id = msg.get("id")
        
        if method == "tools/list":
            response = {
                "jsonrpc": "2.0",
                "id": msg_id,
                "result": {"tools": TOOLS}
            }
            send_message(response)
        
        elif method == "tools/call":
            params = msg.get("params", {})
            tool_name = params.get("name", "")
            tool_params = params.get("arguments", {})
            
            result = handle_tool_call(tool_name, tool_params)
            response = {
                "jsonrpc": "2.0",
                "id": msg_id,
                "result": result
            }
            send_message(response)
        
        elif method == "initialize":
            # Already sent init, but respond to any init requests
            response = {
                "jsonrpc": "2.0",
                "id": msg_id,
                "result": {
                    "protocolVersion": "2024-11-05",
                    "serverInfo": {
                        "name": "mcp-nixos",
                        "version": "0.1.0"
                    },
                    "capabilities": {
                        "tools": {}
                    }
                }
            }
            send_message(response)


if __name__ == "__main__":
    main()
