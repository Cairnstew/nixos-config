# modules/nixos/profiles/system/development.nix
# Development tools and services profile
{ config, lib, pkgs, ... }:
let
  cfg = config.my.profiles.development;
in
{
  config = lib.mkIf cfg.enable {
    # ── Version Control ────────────────────────────────────────────────────
    # mkDefault true: Git is essential for development
    # Override when: Using alternative VCS or container-based dev
    programs.git.enable = lib.mkDefault true;

    # ── Containers & Virtualization ────────────────────────────────────────
    # mkDefault true: Docker standard for development environments
    # Override when: Using Podman, LXD, or no containers
    my.virtualisation.docker.enable = lib.mkDefault true;

    # ── Build Tools ────────────────────────────────────────────────────────
    programs.direnv.enable = lib.mkDefault true;

    # ── Virtualisation ─────────────────────────────────────────────────────
    environment.systemPackages = with pkgs; [ qemu ];

    # ── Secrets Management ─────────────────────────────────────────────────
    # mkDefault true: Development often needs API keys, tokens, etc.
    # Override when: All secrets injected via other means
    agenixManager.enable = lib.mkDefault true;

    # ── Cache ──────────────────────────────────────────────────────────────
    # mkDefault false: Cachix push is opt-in (avoid accidental pushes)
    # Override when: Build host that should push to binary cache
    my.caches.personal.push.enable = lib.mkDefault false;
  };
}
