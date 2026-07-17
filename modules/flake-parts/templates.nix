# =============================================================================
# templates.nix — Flake Templates for Project Scaffolding
# =============================================================================
# Purpose: Provides `nix flake init` templates for bootstrapping new projects
#          with pre-configured development environments.
#
# Inputs: None (self-contained)
#
# Outputs: flake.templates — attrset of templates available via `nix flake init -t .#<name>`
#
# Consumed by: Template directories under `templates/` (relative paths)
# =============================================================================

{ lib, ... }:
let
  # Helper to create a template entry from a directory
  # The path is relative to the flake root
  mkTemplate = name: description: {
    path = ./../../templates/${name};
    inherit description;
  };
in
{
  flake.templates = {
    # Default template (used when running `nix flake init -t .#`)
    default = mkTemplate "default" "Basic project structure with minimal flake.nix";

    # Language-specific templates
    rust = mkTemplate "rust" "Rust project with crane, cargo, and rust-overlay";
    python = mkTemplate "python" "Python project with uv/poetry setup";
    node = mkTemplate "node" "Node.js project with pnpm/npm setup";
    go = mkTemplate "go" "Go project with module support";
    zig = mkTemplate "zig" "Zig project with build.zig";
    haskell = mkTemplate "haskell" "Haskell project with haskell-flake";

    # Nix-specific templates
    nixos-module = mkTemplate "nixos-module" "NixOS module with my.* namespace conventions";
    home-module = mkTemplate "home-module" "Home Manager module structure";
    flake-parts = mkTemplate "flake-parts" "flake-parts module for this repo";

    # Project types
    webapp = mkTemplate "webapp" "Full-stack web application template";
    cli = mkTemplate "cli" "Command-line tool with argument parsing";
    lib = mkTemplate "lib" "Nix library with functions and tests";

    # Python with uv2nix
    uv2nix = mkTemplate "uv2nix" "Python project with uv2nix, uv, and modern tooling";

    # Game development templates
    godot = mkTemplate "godot" "Godot game engine project with GDScript tooling, MCP integration, and .opencode config";
    foundation-mod = mkTemplate "foundation-mod" "Foundation (Timberborn) mod with flake and Lua scaffolding";
    tmodloader = mkTemplate "tmodloader" "tModLoader (Terraria) mod with C# project, flake, and library integrations";
  };
}
