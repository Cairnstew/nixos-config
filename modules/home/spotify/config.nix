{ config, lib, pkgs, ... }:

let
  cfg = config.my.programs.spotify;
  isTui = cfg.tui.enable;
  resolvedPackage = if isTui then cfg.tui.package else cfg.package;
  yamlFormat = pkgs.formats.yaml { };

  # Now-playing waybar widget script
  nowPlayingScript = pkgs.writeShellApplication {
    name = "spotify-now-playing";
    runtimeInputs = [ cfg.player.package pkgs.jq ];
    text = ''
      ${lib.optionalString (cfg.player.credentialsFile != null) ''
        # Parse spotify-cred JSON and export env vars
        if [[ -r "${cfg.player.credentialsFile}" ]]; then
          CREDS="${cfg.player.credentialsFile}"
          SPOTIFY_CLIENT_ID=$(${pkgs.jq}/bin/jq -r '.client_id' "$CREDS")
          export SPOTIFY_CLIENT_ID
          SPOTIFY_CLIENT_SECRET=$(${pkgs.jq}/bin/jq -r '.client_secret // empty' "$CREDS")
          export SPOTIFY_CLIENT_SECRET
          export SPOTIFY_REDIRECT_URI="http://127.0.0.1:8877/callback"
        fi
      ''}

      exec ${cfg.player.package}/bin/python3 ${./now-playing-waybar.py} "$@"
    '';
  };

  # Click handler for the widget (popup-menu control buttons + open/auth)
  spotifyClickScript = pkgs.writeShellApplication {
    name = "spotify-widget-click";
    runtimeInputs = [ cfg.player.package pkgs.jq pkgs.xdg-utils ];
    text = ''
      ${lib.optionalString (cfg.player.credentialsFile != null) ''
        if [[ -r "${cfg.player.credentialsFile}" ]]; then
          CREDS="${cfg.player.credentialsFile}"
          SPOTIFY_CLIENT_ID=$(${pkgs.jq}/bin/jq -r '.client_id' "$CREDS")
          export SPOTIFY_CLIENT_ID
          SPOTIFY_CLIENT_SECRET=$(${pkgs.jq}/bin/jq -r '.client_secret // empty' "$CREDS")
          export SPOTIFY_CLIENT_SECRET
          export SPOTIFY_REDIRECT_URI="http://127.0.0.1:8877/callback"
        fi
      ''}

      exec ${cfg.player.package}/bin/python3 ${./spotify-click.py} "$@"
    '';
  };
in
{
  config = lib.mkIf cfg.enable {
    home.packages = [ resolvedPackage ]
      ++ lib.optionals cfg.player.enable [ nowPlayingScript spotifyClickScript ];

    # The waybar popup-menu XML for the widget now lives in
    # my.desktop.hyprland.bar.menuFiles (system /etc/xdg/waybar, written before
    # switch-time unit restarts — a ~/.config/waybar home-manager file is
    # created too late and waybar's one-shot menu build would miss it).

    home.file.".config/spotatui/config.yml" = lib.mkIf (isTui && cfg.tui.settings != { }) {
      source = yamlFormat.generate "spotatui-config" cfg.tui.settings;
    };
  };
}
