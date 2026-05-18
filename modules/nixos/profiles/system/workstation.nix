# modules/nixos/profiles/system/workstation.nix
# Workstation profile for desktop/laptop systems
{ config, lib, pkgs, ... }:
let
  cfg = config.my.profiles.workstation;
in
{
  config = lib.mkIf cfg.enable {
    # ── Audio & Media ─────────────────────────────────────────────────────
    my.system.audio.enable = lib.mkDefault true;
    my.system.bluetooth.enable = lib.mkDefault true;
    
    # ── Input/Output ───────────────────────────────────────────────────────
    services.printing.enable = lib.mkDefault true;
    services.xserver.xkb.layout = lib.mkDefault "gb";
    
    # ── Common workstation programs ────────────────────────────────────────
    environment.systemPackages = lib.mkDefault (with pkgs; [
      firefox
      thunderbird
      libreoffice
    ]);
    
    # ── Defaults ───────────────────────────────────────────────────────────
    my.programs.spotify.enable = lib.mkDefault true;
    my.virtualisation.docker.enable = lib.mkDefault true;
    my.services.tailscale.enable = lib.mkDefault true;
  };
}
