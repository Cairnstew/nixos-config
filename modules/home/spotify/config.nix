{ config, lib, pkgs, flake, ... }:

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

  # Upvote wrapper for the upstream spotify-playlist-manager CLI — exports the
  # same SPOTIFY_* creds as the other scripts, and reuses the SHARED PKCE
  # token cache (the one spotify-now-playing/spotify-widget-click already
  # authorized) so the upstream never re-runs the interactive auth flow.
  upvoteScript = pkgs.writeShellApplication {
    name = "spotify-upvote";
    runtimeInputs = [ cfg.player.upvote.package pkgs.jq ];
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

      # Upstream reads SPOTIFY_CACHE_PATH or defaults to ".spotify-cache" in
      # its CWD; point it at the shared token cache so it reuses the existing
      # authorization (otherwise every waybar tick re-runs PKCE and 8877 is
      # already in use).
      export SPOTIFY_CACHE_PATH="''${SPOTIFY_CACHE_PATH:-$HOME/.cache/spotify-now-playing-token}"

      exec ${cfg.player.upvote.package}/bin/spotify-playlist-manager waybar upvote "$@"
    '';
  };
in
{
  config = lib.mkIf cfg.enable {
    home.packages = [ resolvedPackage ]
      ++ lib.optionals cfg.player.enable [ nowPlayingScript spotifyClickScript ]
      ++ lib.optionals cfg.player.upvote.enable [ upvoteScript cfg.player.upvote.package ];

    # The waybar popup-menu XML for the widget now lives in
    # my.desktop.hyprland.bar.menuFiles (system /etc/xdg/waybar, written before
    # switch-time unit restarts — a ~/.config/waybar home-manager file is
    # created too late and waybar's one-shot menu build would miss it).

    home.file.".config/spotatui/config.yml" = lib.mkIf (isTui && cfg.tui.settings != { }) {
      source = yamlFormat.generate "spotatui-config" cfg.tui.settings;
    };
  };
}
