{ config, lib, pkgs, flake, ... }:
let
  inherit (lib) mkIf mkMerge;
  cfg = config.my.programs.godot;
  inherit (flake.config.me) username;

  templatesPkg =
    if pkgs ? godot-export-templates then
      pkgs.godot-export-templates
    else
      null;

  godotPkg = if cfg.engine.package != null then cfg.engine.package else pkgs.godot;
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
            exec = "${lib.getBin godotPkg}/bin/godot --path ${project.path}";
          };
        }) cfg.projects
      );

      # ── Shell aliases for quick project access ─────────────────────────
      home.shellAliases = lib.mkMerge [
        (lib.mapAttrs' (name: project: lib.nameValuePair "godot-${name}" ''
          ${lib.getBin godotPkg}/bin/godot --path ${project.path}
        '') cfg.projects)
      ];
    };
  };
}
