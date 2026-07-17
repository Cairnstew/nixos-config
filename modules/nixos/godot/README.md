# Godot Game Engine

Unified NixOS module for Godot game development. Installs the Godot Engine,
export templates, GDScript tooling, MCP server for AI-assisted development,
and optional companion applications.

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `my.programs.godot.enable` | `false` | Enable Godot game engine and tools |
| `my.programs.godot.engine.enable` | `true` | Install Godot Engine editor |
| `my.programs.godot.engine.headless.enable` | `false` | Install Godot headless/server build |
| `my.programs.godot.engine.package` | `null` | Custom Godot package (version pin) |
| `my.programs.godot.exportTemplates.enable` | `false` | Install export templates |
| `my.programs.godot.exportTemplates.autoDownload` | `false` | Auto-place templates in editor dir |
| `my.programs.godot.gdscript.enable` | `false` | GDScript tooling (linter, formatter) |
| `my.programs.godot.mono.enable` | `false` | Mono/C# support — switches engine to godot-mono and installs .NET SDK |
| `my.programs.godot.mcp.enable` | `false` | Godot MCP server for AI assistance |
| `my.programs.godot.companionApps.enable` | `false` | Companion game dev applications |
| `my.programs.godot.companionApps.aseprite` | `false` | Aseprite pixel art editor |
| `my.programs.godot.companionApps.blender` | `false` | Blender 3D modelling |
| `my.programs.godot.companionApps.inkscape` | `false` | Inkscape vector graphics |
| `my.programs.godot.companionApps.audacity` | `false` | Audacity audio editor |
| `my.programs.godot.companionApps.pixelorama` | `false` | Pixelorama sprite editor |
| `my.programs.godot.companionApps.tiled` | `false` | Tiled tile map editor |
| `my.programs.godot.companionApps.texturePacker` | `false` | TexturePacker sprite sheets |
| `my.programs.godot.editor.settingsFile` | `null` | Pre-populate editor settings |
| `my.programs.godot.projects` | `{}` | Declared Godot projects |

## Usage

### Minimal (just the engine)

```nix
my.programs.godot.enable = true;
```

### Full game development setup

```nix
my.programs.godot = {
  enable = true;

  # Engine
  engine.package = pkgs.godot;  # or pin a specific version
  engine.headless.enable = true;

  # Export templates
  exportTemplates = {
    enable = true;
    autoDownload = true;
  };

  # GDScript tooling
  gdscript.enable = true;

  # MCP for AI-assisted development
  mcp.enable = true;

  # Companion apps
  companionApps = {
    enable = true;
    aseprite = true;
    blender = true;
    inkscape = true;
    audacity = true;
    tiled = true;
  };
};
```

### Mono/C# development setup

```nix
my.programs.godot = {
  enable = true;
  mono.enable = true;         # switches engine to godot-mono, adds .NET SDK
  engine.headless.enable = true;
  exportTemplates = {
    enable = true;             # uses mono export templates automatically
    autoDownload = true;
  };
};
```

After applying, open with `godot-mono .` — C# will be available in the Attach Script dialog.

### Declared projects with desktop entries

```nix
my.programs.godot = {
  enable = true;
  projects = {
    "my-rpg" = {
      path = "/home/seanc/Projects/godot/my-rpg";
      renderer = "forward_plus";
      desktopEntries = {
        enable = true;
        icon = "/path/to/icon.png";
      };
    };
    "my-platformer" = {
      path = "/home/seanc/Projects/godot/my-platformer";
      renderer = "gl_compatibility";
    };
  };
};
```

## Notes

- The module installs Godot and related tools system-wide via `environment.systemPackages`.
- Home-manager integration provides export template symlinks, editor settings, and desktop entries.
- GDScript tools are `gdtoolkit_4` (linter/parser) and `gdscript-formatter`.
- `godot-mcp` provides an MCP server for AI-assisted game development (port 3101).
- **Mono/C#**: Enable `my.programs.godot.mono.enable` to use `godot-mono` (C# build). The engine package automatically switches from `pkgs.godot` to `pkgs.godot-mono`, and export templates use `godotPackages.export-templates-mono-bin`. Open the editor with `godot-mono .`.
- **Blank window on Wayland**: If the editor shows a grey/blank window on Wayland, try: `godot-mono --display-driver wayland .` or `godot-mono --rendering-driver opengl3 .`.
- Companion apps are individually opt-in for minimal install footprints.
