{ config, ... }:

let
  cfg = config.my.programs.minecraft;
in
{
  # ── L0: Nix assertions ────────────────────────────────────────────────────
  assertions = [
    {
      assertion = cfg.package == null || cfg.jdks == [ ];
      message = ''
        my.programs.minecraft.jdks only applies to the auto-selected launcher
        package. When my.programs.minecraft.package is set, jdks has no effect —
        apply the override to your custom package instead, e.g.
        prismlauncher.override { jdks = [ pkgs.jdk21 ]; }.
      '';
    }
    {
      assertion = cfg.dataDir == null || cfg.launcher == "prismlauncher";
      message = ''
        my.programs.minecraft.dataDir relies on the prismlauncher --dir flag,
        which the modrinth-app launcher does not support. Keep the default
        launcher (prismlauncher) or leave dataDir unset when using modrinth-app.
      '';
    }
    {
      assertion = cfg.repo == null || cfg.launcher == "prismlauncher";
      message = ''
        my.programs.minecraft.repo syncs the Prism Launcher data directory,
        which only exists for the prismlauncher launcher. Keep the default
        launcher (prismlauncher) or leave repo unset when using modrinth-app.
      '';
    }
    {
      assertion = cfg.repo == null || cfg.repo.conflictStrategy != "reset-hard";
      message = ''
        my.programs.minecraft.repo.conflictStrategy = "reset-hard" is
        DESTRUCTIVE: it discards all local commits on every sync. This data dir
        holds instances and saves — prefer "stash-and-pull" or "ff-only".
      '';
    }
  ];
}
