# modules/nixos/profiles/system/development.nix
# Development tools and services profile
{ config, lib, pkgs, flake, ... }:
let
  inherit (flake.config.me) username;
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

    # ── Game Development ────────────────────────────────────────────────────
    # mkDefault true: Godot engine and basic tools included for game dev
    # Override when: Not doing game development or want a specific version
    my.programs.godot = {
      enable = lib.mkDefault true;
      mono.enable = lib.mkDefault true; # C# support via godot-mono
    };

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

    # ── Git Repo Sync ──────────────────────────────────────────────────────
    # SillyTavern: for developing the custom SillyTavern Nix package
    # Override when: Using a fork, different path, or no local clone
    my.services.gitRepoSync.repos.sillytavern = {
      url = lib.mkDefault "https://github.com/Cairnstew/SillyTavern.git";
      path = lib.mkDefault "/home/${username}/SillyTavern";
      interval = lib.mkDefault "15m";
      conflictStrategy = lib.mkDefault "ff-only";
    };

    # ── OpenCode Web ───────────────────────────────────────────────────────
    # Headless browser UI for opencode. Runs as the primary user (so it picks
    # up ~/.config/opencode + auth.json) and serves the nixos-config repo by
    # default — the repo path comes from gitRepoSync, bridging the two modules.
    # Basic auth via the agenix opencodeWeb-password secret when declared.
    # Override when: Only want opencode web on specific hosts, or a different
    #                default repo / remote bind (see my.services.opencodeWeb).
    my.services.opencodeWeb = {
      enable = lib.mkDefault true;
      user = lib.mkDefault flake.config.me.username;
      repos = lib.mkDefault [ "nix-config" ];
      passwordFile = lib.mkDefault (
        if config.age.secrets ? "opencodeWeb-password"
        then config.age.secrets."opencodeWeb-password".path
        else null
      );
    };
  };
}
