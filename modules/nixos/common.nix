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

    # ── Virtualization ─────────────────────────────────────────────────────
    ./docker
    ./ollama

    # ── Networking ─────────────────────────────────────────────────────────
    ./ssh
    ./tailscale
    inputs.tailscale-manager.nixosModules.default
    ./natShare
    ./nebula

    # ── Development ────────────────────────────────────────────────────────
    ./vscode-server.nix

    # ── Utilities ───────────────────────────────────────────────────────────
    ./udisks2.nix
    ./ventoy
    ./gitreposync
    ./caches
    ./default-build.nix

    # ── ISO Building ────────────────────────────────────────────────────────
    ./live-iso

    # ── Dual-boot / Windows Support ────────────────────────────────────────
    ./disko
    ./dscnix

    # ── Entertainment ──────────────────────────────────────────────────────
    ./spotify.nix
    ./steam
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
    # Default groups: terraform (for IaC), wheel (for sudo)
    # NOTE: docker group is managed by my.virtualisation.docker.users below,
    #       not here, so host extraGroups overrides can't drop it.
    extraGroups = lib.mkDefault [ "terraform" "wheel" ];
  };

  # Ensure the primary user is always in the docker group when docker is enabled.
  # Using the docker module's users option (not extraGroups) so host-level
  # extraGroups overrides can't accidentally drop docker access.
  my.virtualisation.docker.users = [ flake.config.me.username ];

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

      manager = {
        enable = lib.mkDefault true;
        acl.enable = lib.mkDefault true;

        authKeys = lib.mkDefault {
          temp-key = {
            description = "Temporary live environment key";
            tags = [ "tag:temp" ];
            ephemeral = true;
            preauthorized = false;
            recreateIfInvalid = "always";
        exportPath = {
          enable = true;
          owner = "root";
          group = "root";
          mode = "0644";
        };
          };
        };

        policy = {
          enable = lib.mkDefault true;

          tagOwners = lib.mkDefault {
            "tag:nixos" = [ "autogroup:admin" ];
            "tag:temp" = [ "tag:nixos" ];
          };

          interNodePorts = lib.mkDefault [ "tcp:22" ];

          grants = lib.mkDefault [
            {
              src = [ "autogroup:member" ];
              dst = [ "tag:nixos" ];
              ip = [ "tcp:22" ];
            }
            {
              src = [ "tag:nixos" ];
              dst = [ "tag:temp" ];
              ip = [ "*:*" ];
            }
          ];

          ssh = lib.mkDefault [
            {
              action = "accept";
              src = [ "autogroup:admin" ];
              dst = [ "tag:nixos" ];
              users = [ "autogroup:nonroot" "root" ];
            }
            {
              action = "check";
              src = [ "autogroup:member" ];
              dst = [ "tag:nixos" ];
              users = [ "autogroup:nonroot" ];
              checkPeriod = "12h";
            }
            {
              action = "accept";
              src = [ "tag:nixos" ];
              dst = [ "tag:nixos" ];
              users = [ "root" ];
            }
            # 3. Allow your NixOS administrators or NixOS nodes to securely Tailscale-SSH
            # into the temporary live environments for troubleshooting or automation.
            {
              action = "accept";
              src = [ "tag:nixos" ];
              dst = [ "tag:temp" ];
              users = [ "root" "autogroup:nonroot" "nixos" ];
            }
          ];
        };
      };
    };

    # ── Live ISO Definitions ────────────────────────────────────────────
    # Minimal deploy ISO with tailscale auto-auth via pre-provisioned temp key.
    # Auto-deploys to Ventoy USB when ventoy-deploy runs.
    # Build: nix build .#live-iso-deploy
    live.isos.deploy = {
      baseModule = lib.mkDefault "minimal";
      system = lib.mkDefault "x86_64-linux";
      enableSSH = lib.mkDefault true;
      enableFlakes = lib.mkDefault true;
      squashfsCompression = lib.mkDefault "gzip -Xcompression-level 1";
      isoName = lib.mkDefault "nixos-deploy-x86_64.iso";
      volumeID = lib.mkDefault "NIXOS_DEPLOY";

      ventoy = lib.mkDefault true;

      # Tailscale with auto-auth via pre-provisioned temp key
      tailscale.enable = lib.mkDefault true;
      tailscale.authKeyFile = lib.mkDefault "/var/lib/tailscale/authkey";

      extraContents = let
        keyPath = config.services.tailscale-manager.authKeys.temp-key.path;
        keyStorePath = builtins.path {
          path = keyPath;
          name = "tailscale-authkey";
        };
      in [
        {
          source = keyStorePath;
          target = "/var/lib/tailscale/authkey";
        }
      ];

      extraModules = lib.mkDefault [
        { services.tailscale.authKeyFile = "/var/lib/tailscale/authkey"; }
        { services.tailscale.extraUpFlags = lib.mkForce [ "--accept-routes" "--ssh" ]; }
      ];

      extraPackages = lib.mkDefault (with pkgs; [ ]);
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

  # ZFS: Don't force-import root pool by default (safer)
  # Hosts that need it can set boot.zfs.forceImportRoot = true
  boot.zfs.forceImportRoot = lib.mkDefault false;

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
