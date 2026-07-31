{ config, lib, pkgs, flake, ... }:
let
  cfg = config.my.programs.lutris;
  bnet = cfg.battlenet;
  inherit (flake.config.me) username;

  # Build WINEDLLOVERRIDES string from attrs
  dllOverrides = lib.concatStringsSep ";" (lib.mapAttrsToList (k: v: "${k}=${v}") bnet.settings.overrides);

  # Environment variables for Battle.net
  battlenetEnv = bnet.settings.env // {
    WINEESYNC = if bnet.settings.esync then "1" else "0";
    WINEFSYNC = if bnet.settings.fsync then "1" else "0";
    DXVK_HUD = bnet.settings.env.DXVK_HUD or "0";
  } // lib.optionalAttrs (bnet.settings.overrides != { }) {
    WINEDLLOVERRIDES = dllOverrides;
  };

  envExport = lib.concatStringsSep "\n" (lib.mapAttrsToList (k: v: "export ${lib.escapeShellArg k}=${lib.escapeShellArg v}") battlenetEnv);

  # Wrapper script — launches Battle.net directly with system Wine + env vars
  wrapperScript = pkgs.writeShellScriptBin "battlenet" ''
    set -euo pipefail
    PREFIX="$HOME/Games/battlenet"
    BN_EXE="$PREFIX/drive_c/Program Files (x86)/Battle.net/Battle.net.exe"
    WINE="${bnet.wine.package}/bin/wine"
    WINEPREFIX="$PREFIX"

    ${envExport}

    if [ ! -f "$BN_EXE" ]; then
      echo "Battle.net is not installed."
      echo "Open Lutris → click + → search 'Battle.net' → Install"
      echo "After install, run this command again."
      exec "${pkgs.lutris}/bin/lutris"
      exit 1
    fi

    # Kill any stale Battle.net processes from previous runs
    pkill -f "Battle.net.exe" 2>/dev/null || true
    sleep 0.5

    export WINEPREFIX
    exec "$WINE" "$BN_EXE" "$@"
  '';

  # Gamescope-wrapper — same but wrapped
  gamescopeWrapper = pkgs.writeShellScriptBin "battlenet-gamescope" ''
    set -euo pipefail
    PREFIX="$HOME/Games/battlenet"
    BN_EXE="$PREFIX/drive_c/Program Files (x86)/Battle.net/Battle.net.exe"
    WINE="${bnet.wine.package}/bin/wine"
    WINEPREFIX="$PREFIX"

    ${envExport}

    if [ ! -f "$BN_EXE" ]; then
      echo "Battle.net is not installed."
      echo "Open Lutris → click + → search 'Battle.net' → Install"
      exec "${pkgs.lutris}/bin/lutris"
      exit 1
    fi

    pkill -f "Battle.net.exe" 2>/dev/null || true
    sleep 0.5

    export WINEPREFIX
    exec ${pkgs.gamescope}/bin/gamescope \
      ${lib.optionalString (bnet.gamescope.width > 0) "-W ${toString bnet.gamescope.width}"} \
      ${lib.optionalString (bnet.gamescope.height > 0) "-H ${toString bnet.gamescope.height}"} \
      ${lib.optionalString (bnet.gamescope.windowWidth > 0) "-w ${toString bnet.gamescope.windowWidth}"} \
      ${lib.optionalString (bnet.gamescope.windowHeight > 0) "-h ${toString bnet.gamescope.windowHeight}"} \
      ${lib.optionalString (bnet.gamescope.refreshRate != null) "-r ${toString bnet.gamescope.refreshRate}"} \
      ${lib.optionalString bnet.gamescope.fullscreen "-f"} \
      ${lib.concatStringsSep " " bnet.gamescope.extraArgs} \
      -- "$WINE" "$BN_EXE"
  '';

  # Lutris game config — uses JSON (valid YAML) for clean structure
  lutrisGameConfig = pkgs.writeText "battlenet.yml" (builtins.toJSON ({
    game = {
      appid = "battlenet";
      exe = "Battle.net.exe";
      prefix = "$HOME/Games/battlenet";
    };
    wine = {
      version = "system";
      esync = bnet.settings.esync;
      fsync = bnet.settings.fsync;
      dxvk = bnet.settings.dxvk;
      vkd3d = bnet.settings.vkd3d;
    } // lib.optionalAttrs (bnet.settings.overrides != { }) {
      overrides = bnet.settings.overrides;
    };
    system = {
      env = battlenetEnv;
    };
  }));
in
{
  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      lutris
    ] ++ lib.optionals cfg.mangohud.enable [ mangohud ]
    ++ lib.optionals cfg.gamescope.enable [ gamescope ]
    ++ lib.optionals bnet.enable [ bnet.wine.package ]
    ++ lib.optionals (bnet.enable && bnet.winetricks.enable) [ winetricks ]
    ++ lib.optionals (bnet.enable && bnet.protonup.enable) [ protonup-ng ]
    ++ cfg.extraPackages;

    programs.gamemode.enable = lib.mkDefault cfg.gamemode.enable;

    networking.firewall.allowedTCPPorts = lib.mkIf cfg.gamescope.openFirewall [ 47984 47989 48010 ];
    networking.firewall.allowedUDPPorts = lib.mkIf cfg.gamescope.openFirewall [ 47984 47989 48010 ];

    home-manager.users.${username} = lib.mkIf bnet.enable {
      home.packages = [ wrapperScript ] ++ lib.optionals bnet.gamescope.enable [ gamescopeWrapper ];

      # Place Lutris game config so Lutris UI can find Battle.net
      home.file.".config/lutris/games/battlenet.yml".source = lutrisGameConfig;

      xdg.desktopEntries."battlenet" = {
        name = "Battle.net";
        exec = "${wrapperScript}/bin/battlenet";
        icon = "lutris_battlenet";
        categories = [ "Game" "Network" ];
        comment = "Blizzard Battle.net desktop app (system Wine + Wayland fix)";
        terminal = false;
        mimeType = [ "x-scheme-handler/lutris" ];
      };
    };
  };
}
