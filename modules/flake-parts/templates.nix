# =============================================================================
# templates.nix — Flake Templates for Project Scaffolding
# =============================================================================
# Purpose: Provides `nix flake init` templates for bootstrapping new projects
#          with pre-configured development environments.
#
# Inputs: None (self-contained)
#
# Outputs: flake.templates — attrset of templates available via
#          `nix flake init -t <flake-ref>#<name>`.
#          Interactive selection: `nix-template-selector`.
#
# Consumed by: Template directories under `templates/` (relative paths)
# =============================================================================

{ lib, ... }:
let
  # Helper to create a template entry from a directory.
  # The path is relative to the flake root.
  #
  # `welcomeText` is optional markdown shown after a successful init. Add it
  # only where there is a real footgun or non-obvious next step — a template
  # that just says "run nix develop" does not need it, and gets the
  # no-welcomeText form below.
  #
  # Note: `nix flake check` rejects any attribute outside the documented
  # template schema (description, path, welcomeText) — so the Nix attribute
  # must be `welcomeText`, not `welcome`.
  #
  # Note: a `welcomeText ? ""` default cannot be used in a curried Nix lambda
  # (the `?` is parsed as the has-attribute operator), hence the wrapper.
  mkTemplate = name: description: welcomeText: {
    path = ./../../templates/${name};
    inherit description welcomeText;
  };

  mkSimpleTemplate = name: description: mkTemplate name description "";
in
{
  flake.templates = {
    # Default template (used when running `nix flake init -t .#`)
    default = mkSimpleTemplate "default" "Basic project structure with minimal flake.nix";

    # Language-specific templates
    rust = mkSimpleTemplate "rust" "Rust project with crane, cargo, and rust-overlay";
    python = mkSimpleTemplate "python" "Python project with uv/poetry setup";
    node = mkSimpleTemplate "node" "Node.js project with pnpm/npm setup";
    go = mkSimpleTemplate "go" "Go project with module support";
    zig = mkSimpleTemplate "zig" "Zig project with build.zig";
    haskell = mkSimpleTemplate "haskell" "Haskell project with haskell-flake";

    # Nix-specific templates
    nixos-module = mkTemplate "nixos-module" "NixOS module with my.* namespace conventions" ''
      # NixOS module

      Fill in the placeholders — `module.nix` and `README.md` both still
      contain literal `[bracketed]` placeholders.

      ```bash
      rg '\[.*\]' module.nix README.md
      ```
    '';
    home-module = mkSimpleTemplate "home-module" "Home Manager module structure";
    flake-parts = mkTemplate "flake-parts" "flake-parts module for this repo" ''
      # flake-parts module

      Import it from the parent flake's flake-parts layer:

      ```nix
      imports = [ ./modules/flake-parts/my-module.nix ];
      ```
    '';

    # Project types
    webapp = mkSimpleTemplate "webapp" "Full-stack web application template";
    cli = mkSimpleTemplate "cli" "Command-line tool with argument parsing";
    lib = mkSimpleTemplate "lib" "Nix library with functions and tests";

    # Python with uv2nix
    uv2nix = mkTemplate "uv2nix" "Python project with uv2nix, uv, and modern tooling" ''
      # uv2nix project

      ```bash
      nix develop          # dev shell
      uv run --frozen ...  # run with the locked dep tree
      ```

      Dependencies are locked via `uv.lock` and built by Nix. Use `--frozen`
      so Nix and uv agree on the tree.
    '';

    # 3D / VFX templates
    houdini = mkTemplate "houdini" "Houdini project using the system-installed Houdini, with a dev shell, nix run apps, and an MCP-integrated .opencode config" ''
      # Houdini project

      This template has **no** `houdini` package — SideFX Houdini is
      proprietary and not fetchable by Nix. It relies on the `houdini` /
      `hython` wrappers that nixos-config's `my.programs.houdini` module
      installs into `/run/current-system/sw/bin`.

      So this only works on a host with that module enabled.

      **Never add `$HFS/bin` to `PATH`.** That bypasses the module's FHS
      launcher and Houdini crashes on startup. Use the wrappers by name.

      ## MCP server (AI scene control)

      `.opencode/opencode.json` wires an MCP server (stdio, `localhost:18811`)
      into opencode, so an AI assistant can inspect and drive the **running**
      Houdini session — read scene state, create/wire nodes, run Python, render.

      The MCP server only talks to a live session, so **start `hrpyc` in
      Houdini first** (Python Shell, or add it to `123.py`):

      ```python
      import hrpyc
      hrpyc.start_server(port=18811)
      ```

      Standalone (no opencode): `nix run .#houdini-mcp` — HTTP on `:3055`,
      health check at `/health`.

      `.opencode/opencode.json` has to reference this project by **absolute**
      path: opencode spawns MCP servers from its web daemon's cwd, not the
      project, so a `.#houdini-mcp` ref fails there with `could not find a
      flake.nix file` (reported only as `server unavailable … status=failed`).
      The path is unknowable until the project exists, so the shell hook
      **regenerates `.opencode/opencode.json` on every `nix develop`** — enter
      the shell once before expecting opencode to find the server. It uses
      `/run/current-system/sw/bin/nix` for the same reason (`nix` is absent from
      the daemon's restricted `PATH`). The env block is keyed `environment`,
      not `env` — opencode silently drops unrecognised keys, and a dropped
      `MCP_TRANSPORT=stdio` sends the server to HTTP :3055, where opencode
      times it out after 30 s and only reports `status=failed`.
    '';

    # Game development templates
    godot = mkSimpleTemplate "godot" "Godot game engine project with GDScript tooling, MCP integration, and .opencode config";
    foundation-mod = mkSimpleTemplate "foundation-mod" "Foundation (Timberborn) mod with flake and Lua scaffolding";
    tmodloader = mkSimpleTemplate "tmodloader" "tModLoader (Terraria) mod with C# project, flake, and library integrations";
  };
}
