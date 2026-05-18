# modules/nixos/profiles/system/development.nix
# Development tools and services profile
{ config, lib, ... }:
let
  cfg = config.my.profiles.development;
in
{
  config = lib.mkIf cfg.enable {
    # ── Version Control ────────────────────────────────────────────────────
    programs.git.enable = lib.mkDefault true;
    
    # ── Containers & Virtualization ────────────────────────────────────────
    my.virtualisation.docker.enable = lib.mkDefault true;
    
    # ── Build Tools ────────────────────────────────────────────────────────
    programs.direnv.enable = lib.mkDefault true;
    
    # ── Secrets Management ─────────────────────────────────────────────────
    my.secrets.enable = lib.mkDefault true;
    
    # ── Cache ──────────────────────────────────────────────────────────────
    my.services.cachix-push.enable = lib.mkDefault false; # Explicit opt-in
  };
}
