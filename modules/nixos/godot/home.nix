{ config, lib, pkgs, flake, ... }:
let
  inherit (lib) mkIf mkMerge;
  cfg = config.my.programs.godot;
  inherit (flake.config.me) username;

  templatesPkg =
    if cfg.mono.enable && pkgs ? godotPackages.export-templates-mono-bin then
      pkgs.godotPackages.export-templates-mono-bin
    else if pkgs ? godot-export-templates-bin then
      pkgs.godot-export-templates-bin
    else
      null;

  godotPkg =
    if cfg.engine.package != null then cfg.engine.package
    else if cfg.mono.enable then pkgs.godot-mono
    else pkgs.godot;

  godotBin = "${lib.getBin godotPkg}/bin/${if cfg.mono.enable then "godot-mono" else "godot"}";
in
{
  config = mkIf (cfg.enable && cfg.editor.enable) {
    home-manager.users.${username} = {
      home = {
        # ── Export Templates ─────────────────────────────────────────────────
        file = mkMerge [
          (mkIf (cfg.exportTemplates.enable && cfg.exportTemplates.autoDownload && templatesPkg != null) {
            "${cfg.exportTemplates.targetDir}/".source =
              "${templatesPkg}/share/godot/export_templates";
          })

          (mkIf (cfg.editor.settingsFile != null) {
            ".local/share/godot/editor_settings.tres".source = cfg.editor.settingsFile;
          })

          (mkIf (cfg.editor.projectManager.favoriteDirectories != [ ]) {
            ".config/godot/project-favorites.txt".text =
              lib.concatStringsSep "\n" cfg.editor.projectManager.favoriteDirectories;
          })
        ];
      };

      # ── Desktop Entries for Projects ─────────────────────────────────────
      xdg.desktopEntries = lib.mkMerge (
        lib.mapAttrsToList (name: project: mkIf project.desktopEntries.enable {
          "godot-${name}" = {
            name = name;
            icon = if project.desktopEntries.icon != null then project.desktopEntries.icon else "godot";
            categories = project.desktopEntries.categories;
            exec = "${godotBin} --path ${project.path}";
          };
        }) cfg.projects
      );

      # ── Shell aliases for quick project access ─────────────────────────
      home.shellAliases = lib.mkMerge [
        (lib.mapAttrs' (name: project: lib.nameValuePair "godot-${name}" ''
          ${godotBin} --path ${project.path}
        '') cfg.projects)
      ];
    };
  };
}
