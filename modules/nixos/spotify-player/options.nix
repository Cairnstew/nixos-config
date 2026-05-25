{ lib, ... }:
let
  types = lib.types;
in
{
  options.my.programs.spotify = {
    enable = lib.mkOption {
      type = types.bool;
      default = false;
      description = "Enable spotify-player: a terminal Spotify client with streaming and Spotify Connect";
    };

    clientIdFile = lib.mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "Path to a file containing the Spotify API client ID. Used by client_id_command in app.toml.";
    };
  };
}
