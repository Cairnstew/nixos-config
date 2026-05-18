# modules/nixos/profiles/system/server.nix
# Server profile for headless systems
{ config, lib, ... }:
let
  cfg = config.my.profiles.server;
in
{
  config = lib.mkIf cfg.enable {
    # ── SSH ────────────────────────────────────────────────────────────────
    my.services.ssh.enable = lib.mkDefault true;
    
    # ── Services ───────────────────────────────────────────────────────────
    my.services.tailscale.enable = lib.mkDefault true;
    
    # ── No GUI ─────────────────────────────────────────────────────────────
    my.system.audio.enable = lib.mkDefault false;
    my.system.bluetooth.enable = lib.mkDefault false;
    
    # ── Defaults ───────────────────────────────────────────────────────────
    my.programs.spotify.enable = lib.mkDefault false;
    
    # ── Secrets ────────────────────────────────────────────────────────────
    my.secrets.enable = lib.mkDefault true;
  };
}
