# modules/nixos/common.nix
# Common configuration imported by ALL NixOS hosts
# This is the single entry point for shared system configuration
{ flake, lib, config, pkgs, ... }:
let
  inherit (flake) inputs;
  inherit (inputs) self;

  # Helper to check if this is a WSL system
  isWSL = config.wsl.enable or false;
in
{
  imports = [
    # ── Core System ────────────────────────────────────────────────────────
    ./nix.nix
    ./primary-as-admin.nix
    ./self-ide.nix
    ./_1password

    # ── Hardware ───────────────────────────────────────────────────────────
    ./audio
    ./battery
    ./bluetooth.nix
    ./graphics

    # ── Desktop ────────────────────────────────────────────────────────────
    ./gnome
    ./plasma-x11.nix

    # ── Virtualization ─────────────────────────────────────────────────────
    ./docker
    ./waydroid.nix
    ./ollama

    # ── Networking ─────────────────────────────────────────────────────────
    ./ssh
    ./tailscale
    ./natShare
    ./nebula
    ./rustdesk.nix

    # ── Development ────────────────────────────────────────────────────────
    ./vscode-server.nix

    # ── Utilities ───────────────────────────────────────────────────────────
    ./brasero.nix
    ./udisks2.nix
    ./ventoy.nix
    ./gitreposync
    ./cachix-push
    ./default-build.nix

    # ── Dual-boot / Windows Support ────────────────────────────────────────
    ./disko
    ./windows-installer
    ./dscnix

    # ── Entertainment ──────────────────────────────────────────────────────
    ./spotify.nix
    ./sillytavern

    # ── Location & Secrets ────────────────────────────────────────────────
    ./current-location.nix
    ./secrets

    # ── VM Testing ──────────────────────────────────────────────────────────
    ./vm-test.nix

    # ── Profiles System ────────────────────────────────────────────────────
    ./profiles

    # ── Home Manager Integration ───────────────────────────────────────────
    ./homeManager

    # ── External Modules ───────────────────────────────────────────────────
    inputs.agenix.nixosModules.default
    inputs.nixos-wsl.nixosModules.default
  ];

  # ── Base System Configuration ────────────────────────────────────────────

  # User setup
  users.users.${flake.config.me.username} = {
    # mkDefault true: Allow hosts to mark users as system users if needed
    # Override when: Creating system/service accounts that shouldn't have
    #                normal user privileges or home directories
    isNormalUser = lib.mkDefault true;

    # mkDefault for groups: Allows hosts to add additional groups
    # Default groups: terraform (for IaC), docker (for containers), wheel (for sudo)
    # Override when: Host needs additional groups (e.g., video, audio, plugdev)
    extraGroups = lib.mkDefault [ "terraform" "docker" "wheel" ];
  };

  # ── Sensible Defaults ────────────────────────────────────────────────────

  my = {
    # Secrets enabled by default: Safe to have enabled as agenix gracefully
    # handles missing secret files. Disabling is mainly for containers or
    # minimal systems where secret management isn't needed.
    # Override when: Building minimal containers or systems without persistent storage
    secrets.enable = lib.mkDefault true;

    # SSH always enabled: Essential for remote management and debugging.
    # Disable only on fully air-gapped systems or WSL where host manages SSH.
    # Override when: WSL instances (use Windows OpenSSH) or isolated systems
    services.ssh.enable = lib.mkDefault true;

    # Tailscale defaults: VPN/mesh networking for secure remote access
    # mkDefault allows hosts to customize tags, disable, or change settings
    services.tailscale = {
      # Enable by default: Most systems benefit from Tailscale connectivity
      # Override when: Systems without internet or using alternative VPNs
      enable = lib.mkDefault true;

      # Default tag for all NixOS systems: Used for ACLs and filtering
      # Override when: Different role (server, laptop, iot, etc.)
      tags = lib.mkDefault [ "tag:nixos" ];

      ssh = {
        # Enable Tailscale SSH: Allows SSH access via Tailscale auth
        # Override when: Using traditional SSH exclusively
        enable = lib.mkDefault true;

        # Default user for Tailscale SSH connections
        # Override when: Different primary username on host
        user = lib.mkDefault flake.config.me.username;

        # Forward SSH agent: Uses preference from config.ssh.forwardAgent
        # Override when: Agent forwarding is a security concern on this host
        extraHostConfig = lib.mkDefault (if (flake.config.ssh.forwardAgent or true) then "ForwardAgent yes" else "ForwardAgent no");
      };
    };

    # Git repo sync: Automatically syncs this flake to GitHub
    # Enabled by default: Ensures config changes are backed up
    # Override when: Ephemeral systems or manual git management preferred
    services.gitRepoSync = {
      enable = lib.mkDefault true;
      user = lib.mkDefault flake.config.me.username;
      repos.nix-config = {
        # URL for the upstream repository
        # Override when: Using a fork or different remote
        url = lib.mkDefault "https://github.com/Cairnstew/nixos-config.git";

        # Local path where repo is cloned
        # Override when: Different home directory structure
        path = lib.mkDefault "/home/${flake.config.me.username}/nixos-config";

        # Sync interval: How often to check for changes
        # Override when: More/less frequent sync needed
        interval = lib.mkDefault "5m";

        # Conflict strategy: ff-only prevents accidental overwrites
        # Override when: Two-way sync or manual conflict resolution needed
        conflictStrategy = lib.mkDefault "ff-only";
      };
    };
  };

  # ── Boot Configuration ───────────────────────────────────────────────────
  # Note: Bootloader configuration (grub/systemd-boot) is host-specific
  # and should be configured in the host's configuration.nix
  # This prevents grub from being implicitly enabled
  # mkDefault false: Ensures no bootloader is forced; host must opt-in
  # Override when: System needs grub (BIOS) or systemd-boot (UEFI)
  boot.loader.grub.enable = lib.mkDefault false;

  # ── Environment ──────────────────────────────────────────────────────────
  # Base packages available on all hosts
  environment.systemPackages = with pkgs; [
    nix-template-selector # Interactive flake template selector
    github-actions-cleanup # GitHub Actions cleanup tool
  ];

  # Additional packages are defined per-host or use environment.systemPackages directly

  # ── Assertions ───────────────────────────────────────────────────────────
  # Note: Profile mutual-exclusivity assertions live in profiles/system/default.nix
}
