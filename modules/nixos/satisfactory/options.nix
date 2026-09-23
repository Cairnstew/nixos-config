{ lib, ... }:
let
  inherit (lib) mkOption mkEnableOption types;
in
{
  options.my.programs.satisfactory = {
    enable = mkEnableOption "Satisfactory game with modding support";

    modding = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Enable modding support for Satisfactory. Installs
          <literal>ficsit-cli</literal> for managing mods from the command
          line or TUI, and sets up the Satisfactory Mod Manager (SMM) for
          GUI-based mod management.

          Mods are installed into the game's Proton prefix at
          <literal>&lt;steam-library&gt;/steamapps/compatdata/1690809/pfx/drive_c/users/steamuser/AppData/Local/FactoryGame/Mods/</literal>.
          Use <literal>ficsit-cli</literal> to manage them — see
          <link xlink:href="https://docs.ficsit.app/satisfactory-modding/latest/ForUsers/SatisfactoryModManager.html">the modding docs</link>.
        '';
      };
    };

    dedicatedServer = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Open firewall ports for a Satisfactory dedicated server.
          The dedicated server is a separate installation managed via
          SteamCMD or manual download — not the same as the game client.
        '';
      };

      gamePort = mkOption {
        type = types.port;
        default = 15777;
        description = "UDP port for the Satisfactory dedicated server game traffic.";
      };

      queryPort = mkOption {
        type = types.port;
        default = 15778;
        description = "UDP port for server query/status.";
      };

      beaconPort = mkOption {
        type = types.port;
        default = 15779;
        description = "UDP port for server beacon/discovery.";
      };
    };
  };
}
