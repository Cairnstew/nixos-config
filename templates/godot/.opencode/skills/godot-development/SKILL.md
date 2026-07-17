---
name: godot-development
description: Godot game development with GDScript, C#, and Nix integration
---

## What I do

Guide Godot game development within a Nix flake environment using the Godot engine (mono/C# build), GDScript, and Nix dev shell.

## Project Structure

```
.
├── default/
│   ├── default_env.tres     # Default environment settings
│   └── main.tscn            # Main scene (Node2D root)
├── .godot/                  # Editor metadata (auto-generated)
├── project.godot            # Godot project configuration
├── export_presets.cfg       # Linux/X11 export preset
├── flake.nix                # Nix flake with dev shell
├── .opencode/
│   ├── opencode.json        # OpenCode config with pinned godot-mcp
│   └── skills/
│       └── godot-development/
│           └── SKILL.md     # This file
└── .envrc                   # direnv integration
```

## Common Tasks

### Open the project in the editor

```bash
godot-mono .
```

### Run the project (debug mode)

```bash
godot-mono --path .
```

### Run headless (CI/CD)

```bash
godot-mono --headless --path . --quit
```

### Export the project

```bash
godot-mono --export-release Linux/X11 ./exports/my-game.x86_64
```

### Lint GDScript

```bash
gdlint .
```

### Format GDScript

```bash
gdformat .
```

### Create a C# script (from the editor)

Open the editor, right-click a node > "Attach Script", select C# as language.

### Development shell

```bash
nix develop
# Or with direnv
direnv allow
```

## Key Tools Available

- `godot-mono` - Godot Engine editor + CLI runner (with C# support)
- `dotnet` - .NET SDK 8.0 (required by godot-mono for C# scripting)
- `godot-export-templates-mono-bin` - Export templates for Linux/X11
- `godot-mcp` - Pinned MCP server (v0.1.1) for AI-assisted development
- `godotpcktool` - .pck file extraction and creation
- `gdtoolkit_4` - GDScript linter (`gdlint`) and parser
- `gdscript-formatter` - Fast GDScript formatter (`gdformat`)
- `nodejs` - Node.js runtime
- `git` - Version control

## MCP Integration

This project bundles [godot-mcp](https://github.com/Coding-Solo/godot-mcp) v0.1.1 as a pinned Nix derivation. Tools available:

- `launch_editor` - Open the Godot editor for a project
- `run_project` - Run a Godot project in debug mode *(requires confirmation)*
- `get_debug_output` - Capture console output/errors
- `stop_project` - Stop a running project
- `create_scene` - Create new scenes with root node type *(requires confirmation)*
- `add_node` - Add nodes to existing scenes *(requires confirmation)*
- `load_sprite` - Load sprites into Sprite2D nodes *(requires confirmation)*
- `export_mesh_library` - Export scenes as MeshLibrary *(requires confirmation)*
- `save_scene` - Save changes to scenes *(requires confirmation)*
- `update_project_uids` - Update UID references *(requires confirmation)*
- `get_project_info` - Get project structure info
- `get_godot_version` - Get installed Godot version

Destructive tools (`create_scene`, `add_node`, `load_sprite`, `export_mesh_library`, `save_scene`, `update_project_uids`, `run_project`) require explicit confirmation.

## References

- [Godot Engine Documentation](https://docs.godotengine.org/en/stable/)
- [GDScript Reference](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_basics.html)
- [Godot C# Documentation](https://docs.godotengine.org/en/stable/tutorials/scripting/c_sharp/)
- [Godot MCP Server](https://github.com/Coding-Solo/godot-mcp)
