{ config, lib, pkgs, flake, ... }:
let
  cfg = config.my.programs.spotify;
  me = flake.config.me;
  hasToken = config.age.secrets ? "spotify-token";
in
{
  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      spotify-player
    ];

    networking.firewall.allowedUDPPorts = [
      5353 # Spotify Connect discovery (mDNS)
    ];

    my.programs.spotify.clientIdFile =
      if hasToken
      then config.age.secrets."spotify-token".path
      else null;

    my.homeManager.extraConfig.xdg.configFile."spotify-player/app.toml" = lib.mkIf hasToken {
      text = ''
        client_id_command = { command = "cat", args = ["${config.age.secrets."spotify-token".path}"] }
      '';
    };
  };
}
