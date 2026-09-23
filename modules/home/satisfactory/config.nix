{ config, lib, pkgs, ... }:
let
  cfg = config.my.programs.satisfactory;
in
{
  config = lib.mkIf cfg.enable {
    home.packages = [
      pkgs.ficsit-cli
      pkgs.satisfactorymodmanager
      # Launch helper: launches Satisfactory via Steam with mods
      (pkgs.writeShellScriptBin "satisfactory-modded" ''
        # Launch Satisfactory via Steam with SML/mods loaded.
        # Mod loading is handled by SML inside the Proton prefix once
        # installed via ficsit-cli or Satisfactory Mod Manager.

        ${lib.optionalString (cfg.gameDir != null) ''
          echo "Game directory: ${cfg.gameDir}"
        ''}
        echo "Use ficsit-cli to manage mods:"
        echo "  ficsit-cli              # Interactive TUI"
        echo "  ficsit-cli help         # Show commands"

        exec ${lib.getBin pkgs.steam}/bin/steam steam://rungameid/1690809
      '')
    ] ++ cfg.extraPackages;

    # ── Shell alias ────────────────────────────────────────────────────────
    programs.bash.shellAliases = {
      sf = "ficsit-cli";
    };
  };
}
