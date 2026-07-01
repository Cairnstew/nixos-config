{ config, lib, pkgs, flake, ... }:
let
  cfg = config.my.programs.godot;

  godotPkg = if cfg.engine.package != null then cfg.engine.package else pkgs.godot;

  headlessPkg =
    if cfg.engine.headless.package != null then
      cfg.engine.headless.package
    else if pkgs ? godot-headless then
      pkgs.godot-headless
    else
      null;

  exportTemplatesPkg =
    if cfg.exportTemplates.package != null then
      cfg.exportTemplates.package
    else if pkgs ? godot-export-templates-bin then
      pkgs.godot-export-templates-bin
    else
      null;
in
{
  config = lib.mkIf cfg.enable {
    # ── Godot Engine Packages ────────────────────────────────────────────────
    environment.systemPackages =
      (lib.optional cfg.engine.enable godotPkg)
      ++ (lib.optional (cfg.engine.headless.enable && headlessPkg != null) headlessPkg)
      ++ (lib.optional cfg.pckTool pkgs.godotpcktool)

    # ── GDScript Tooling ─────────────────────────────────────────────────────
      ++ (lib.optional (cfg.gdscript.enable && cfg.gdscript.gdtoolkit) pkgs.gdtoolkit_4)
      ++ (lib.optional (cfg.gdscript.enable && cfg.gdscript.formatter) pkgs.gdscript-formatter)

    # ── MCP Server ───────────────────────────────────────────────────────────
      ++ (lib.optional cfg.mcp.enable pkgs.godot-mcp)

    # ── Companion Applications ───────────────────────────────────────────────
      ++ (lib.optional (cfg.companionApps.enable && cfg.companionApps.pixelorama) pkgs.pixelorama)
      ++ (lib.optional (cfg.companionApps.enable && cfg.companionApps.aseprite) pkgs.aseprite)
      ++ (lib.optional (cfg.companionApps.enable && cfg.companionApps.blender) pkgs.blender)
      ++ (lib.optional (cfg.companionApps.enable && cfg.companionApps.inkscape) pkgs.inkscape)
      ++ (lib.optional (cfg.companionApps.enable && cfg.companionApps.audacity) pkgs.audacity)
      ++ (lib.optional (cfg.companionApps.enable && cfg.companionApps.texturePacker) pkgs.texturepacker)
      ++ (lib.optional (cfg.companionApps.enable && cfg.companionApps.tiled) pkgs.tiled)
      ++ (lib.optionals (cfg.companionApps.enable) cfg.companionApps.extraPackages)
      ++ (lib.optional (exportTemplatesPkg != null) exportTemplatesPkg)
      ++ (lib.optional (cfg.mono.enable && pkgs ? dotnet-sdk) pkgs.dotnet-sdk);

    # ── Firewall Rules ───────────────────────────────────────────────────────
    networking.firewall.allowedTCPPorts = lib.mkIf (cfg.mcp.enable && cfg.mcp.openFirewall) [
      cfg.mcp.port
    ];

    # ── warnings for missing packages ────────────────────────────────────────
    warnings =
      (lib.optional (cfg.engine.headless.enable && headlessPkg == null) ''
        my.programs.godot.engine.headless is enabled but no headless package
        is available in nixpkgs for your system.
      '')
      ++ (lib.optional (cfg.mono.enable && !(pkgs ? dotnet-sdk)) ''
        my.programs.godot.mono is enabled but dotnet-sdk is not available.
        Godot Mono/C# support requires the .NET SDK to be installed.
      '');
  };
}
