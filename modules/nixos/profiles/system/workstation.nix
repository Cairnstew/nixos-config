# modules/nixos/profiles/system/workstation.nix
# Workstation profile for desktop/laptop systems
{ config, lib, pkgs, ... }:
let
  cfg = config.my.profiles.workstation;
in
{
  config = lib.mkIf cfg.enable {
    # ── Audio & Media ─────────────────────────────────────────────────────
    # mkDefault true: Workstations typically need audio/bluetooth
    # Override when: Headless workstation or audio handled differently
    my.system.audio.enable = lib.mkDefault true;
    my.system.bluetooth.enable = lib.mkDefault true;

    # ── Input/Output ───────────────────────────────────────────────────────
    # mkDefault for printing: Most workstations need printer support
    # Override when: No printers used or CUPS not desired
    services.printing.enable = lib.mkDefault true;

    # UK keyboard layout as default (GB locale)
    # Override when: Different regional layout needed
    services.xserver.xkb.layout = lib.mkDefault "gb";

    # ── Common workstation programs ────────────────────────────────────────
    # mkDefault for packages: Core GUI apps for daily use
    # Override when: Different browser/office suite preferred, or minimal setup
    environment.systemPackages = lib.mkDefault (with pkgs; [
      firefox
      thunderbird
      libreoffice
    ]);

    # ── Defaults ───────────────────────────────────────────────────────────
    # mkDefault true: Common workstation apps/services
    # Override when: Not using Spotify, Docker, or Tailscale
    my.programs.spotify.enable = lib.mkDefault true;
    my.virtualisation.docker.enable = lib.mkDefault true;
    my.services.tailscale.enable = lib.mkDefault true;
  };
}
