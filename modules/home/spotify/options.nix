{ lib, pkgs, flake, ... }:

let
  inherit (lib) types;
  spotifyPlaylistMgr = flake.inputs.spotify-playlist-manager.packages.${pkgs.system}.default;
in
{
  options.my.programs.spotify = {
    enable = lib.mkEnableOption "Spotify desktop client";

    package = lib.mkOption {
      type = types.package;
      default = pkgs.spotify;
      defaultText = lib.literalExpression "pkgs.spotify";
      description = "The Spotify package to use.";
    };

    tui = {
      enable = lib.mkEnableOption "spotatui TUI client";

      package = lib.mkOption {
        type = types.package;
        default = pkgs.spotatui;
        defaultText = lib.literalExpression "pkgs.spotatui";
        description = "The Spotify TUI package to use (default: spotatui, a community fork of spotify-tui).";
      };

      settings = lib.mkOption {
        type = types.attrs;
        default = { };
        example = {
          behavior = {
            enable_discord_rpc = false;
          };
        };
        description = ''
          Settings to write to ~/.config/spotatui/config.yml.
          See https://github.com/LargeModGames/spotatui/wiki/Configuration
          for the full config reference.
        '';
      };
    };

    player = {
      enable = lib.mkEnableOption "Spotify now-playing widget for Waybar";

      interval = lib.mkOption {
        type = types.ints.positive;
        default = 5;
        example = 3;
        description = "Polling interval in seconds for the now-playing widget.";
      };

      package = lib.mkOption {
        type = types.package;
        default = pkgs.python3.withPackages (ps: [ ps.spotipy ]);
        defaultText = lib.literalExpression "pkgs.python3.withPackages (ps: [ ps.spotipy ])";
        description = "Python environment with spotipy for the now-playing script.";
      };

      credentialsFile = lib.mkOption {
        type = types.nullOr types.path;
        default = null;
        example = "/run/secrets/spotify-cred";
        description = ''
          Path to a file sourced as environment before running the widget.
          Must export SPOTIFY_CLIENT_ID and SPOTIFY_REDIRECT_URI.
          When null, expects the variables to already be in the environment
          (e.g. via direnv or home.sessionVariables).
        '';
      };

      upvote = {
        enable = lib.mkEnableOption "Spotify upvote button for Waybar";

        package = lib.mkOption {
          type = types.package;
          default = spotifyPlaylistMgr;
          defaultText = lib.literalExpression "flake.inputs.spotify-playlist-manager.packages.<system>.default";
          description = ''
            The spotify-playlist-manager package (upstream flake input).
            Provides the `spotify-playlist-manager waybar upvote` CLI used by
            the waybar module. The upstream is developed via the ensemble space
            (spotify-playlist-manager); see modules/AGENT.md §4.2.
          '';
        };
      };
    };
  };
}
