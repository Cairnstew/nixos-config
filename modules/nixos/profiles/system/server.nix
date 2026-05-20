# modules/nixos/profiles/system/server.nix
# Server profile for headless systems
{ config, lib, ... }:
let
  cfg = config.my.profiles.server;
in
{
  config = lib.mkIf cfg.enable {
    # ── SSH ────────────────────────────────────────────────────────────────
    # mkDefault true: SSH is critical for headless server management
    # Override when: Serial console or out-of-band management only
    my.services.ssh.enable = lib.mkDefault true;

    # ── Services ───────────────────────────────────────────────────────────
    # mkDefault true: Tailscale for secure remote access
    # Override when: On-premise only with no remote access needed
    my.services.tailscale.enable = lib.mkDefault true;

    # ── No GUI ─────────────────────────────────────────────────────────────
    # mkDefault false: Servers don't need audio/bluetooth
    # Override when: Media server or special use case
    my.system.audio.enable = lib.mkDefault false;
    my.system.bluetooth.enable = lib.mkDefault false;

    # ── Defaults ───────────────────────────────────────────────────────────
    # mkDefault false: Spotify not needed on headless servers
    # Override when: Media server with Spotify Connect
    my.programs.spotify.enable = lib.mkDefault false;

    # ── Secrets ────────────────────────────────────────────────────────────
    # mkDefault true: Servers typically need secrets for services
    # Override when: Minimal server without secret-dependent services
    my.secrets.enable = lib.mkDefault true;
  };
}
