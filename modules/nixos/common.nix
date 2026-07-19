# modules/nixos/common.nix
# Common configuration imported by ALL NixOS hosts
# This is the single entry point for shared system configuration
{ flake, lib, config, pkgs, ... }:
let
  inherit (flake) inputs;
  inherit (inputs) self;

  # Helper to check if this is a WSL system
  isWSL = config.wsl.enable or false;

  # agenix-manager key groups — defined here to avoid circular config references
  # in keys.groups.main below.
  systemsKeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIETE96NnwPAZ0n5y6XcCzoErkrAhulUht/Hho0V829Qy root@laptop" # laptop
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIZ1mor/quSbisUKJivp3lMDvMcQR4wojD/l5Etg6KCV root@server" # server
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKWiP0JxNaeWS30gzg4A2zLnSRdZutWzCP0mjZit7/De seanc@desktop" # desktop
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKekVg/4uXAmOcRzxbaPn9zW5NTB6te+F0PUXO1FmrkQ seanc@laptop" # nixos-deploy/desktop
  ];
  usersKeys = [ flake.config.me.sshKey ];
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
    ./hyprland
    ./monitors
    ./mouse

    # ── Virtualization ─────────────────────────────────────────────────────
    ./docker
    ./ollama

    # ── Reverse Proxy ───────────────────────────────────────────────────────
    ./proxy

    # ── AI Frontends ────────────────────────────────────────────────────────
    ./open-webui
    ./letta
    ./jan

    # ── Networking ─────────────────────────────────────────────────────────
    ./ssh
    ./tailscale
    ./tailscale-watchdog
    inputs.tailscale-manager.nixosModules.default
    ./natShare
    ./nebula
    ./zerotier

    # ── Development ────────────────────────────────────────────────────────
    ./vscode-server.nix

    # ── Utilities ───────────────────────────────────────────────────────────
    ./udisks2.nix
    ./ventoy
    ./gitreposync
    ./email-alerts
    ./caches
    ./default-build.nix

    # ── ISO Building ────────────────────────────────────────────────────────
    ./live-iso

    # ── Dual-boot / Windows Support ────────────────────────────────────────
    ./disko
    ./dscnix

    # ── Entertainment & Game Development ──────────────────────────────────
    ./spotify.nix
    ./steam
    ./proton
    ./godot
    ./sillytavern
    ./risuai
    ./suwayomi

    # ── TV & EPG ─────────────────────────────────────────────────────────
    ./xmltv

    # ── Media Stack (*arr) ────────────────────────────────────────────────
    ./prowlarr
    ./sonarr
    ./radarr
    ./jellyfin

    ./chatterbox-tts
    ./moku.nix
    ./boot-alerting
    ./boot-health

    # ── Location, Secrets & Deploy ────────────────────────────────────────
    ./current-location.nix
    ./secrets
    ./deploy

    # ── Privacy ─────────────────────────────────────────────────────────────
    ./tor-browser

    # ── Theming ─────────────────────────────────────────────────────────────
    ./stylix

    # ── Testing / VM ────────────────────────────────────────────────────────
    ./test-runner
    ./vm

    # ── Profiles System ────────────────────────────────────────────────────
    ./profiles

    # ── Home Manager Integration ───────────────────────────────────────────
    ./homeManager

    # ── External Modules ───────────────────────────────────────────────────
    inputs.agenix.nixosModules.default
    inputs.agenix-manager.nixosModules.default
    inputs.nixos-wsl.nixosModules.default
    inputs.stylix.nixosModules.stylix
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
    extraGroups = lib.mkDefault [ "networkmanager" "terraform" "wheel" ]; # M4b: added networkmanager so hosts with matching config can drop their override
  };

  # Ensure the primary user is always in the docker group when docker is enabled.
  # Using the docker module's users option (not extraGroups) so host-level
  # extraGroups overrides can't accidentally drop docker access.
  my.virtualisation.docker.users = [ flake.config.me.username ];

  agenixManager = {
    enable = true;
    secretsPath = ./secrets;

    keys.groups.systems = systemsKeys;
    keys.groups.users = usersKeys;
    keys.groups.main = systemsKeys ++ usersKeys;

    keys.groups.deployment = [ "age1hd4asmw7agdq8ygy8hu4w8mdxalevkmne9x3zwcawsjdze9spcnqpmhtse" ];

    identities = [ "/etc/ssh/ssh_host_ed25519_key" ];
  };

  # Override the upstream agenixManagerSecretsNix activation script to NOT
  # overwrite secrets-manifest.json. The module writes 4 files to /etc/agenix/
  # on every rebuild:
  #   secrets.nix              ← OK to overwrite (eval-time derived)
  #   agenix-manager-cache.json ← OK to overwrite (eval-time derived)
  #   keys-snapshot.json       ← OK to overwrite (eval-time derived)
  #   secrets-manifest.json    ← DO NOT OVERWRITE (preserves CLI changes)
  #
  # The manifest is the CLI's source of truth for runtime operations like
  # `agenix-manager status`. Overwriting it on every rebuild destroys any
  # secrets the user added via `agenix-manager new` but hasn't committed yet.
  # The Nix evaluation reads the manifest from the repo file at build time
  # (via cfg.manifestPath), so decryption still works correctly regardless.
  system.activationScripts.agenixManagerSecretsNix = {
    text = lib.mkForce (
      let
        cfg = config.agenixManager;
        secretsNixFile = pkgs.writeText "secrets.nix" cfg.secretsNixContent;
        cliConfigFile = pkgs.writeText "agenix-manager-cache.json" (builtins.toJSON cfg.cliConfig);
        keysSnapshotFile = pkgs.writeText "keys-snapshot.json" (builtins.toJSON
          (builtins.listToAttrs (map (s: lib.nameValuePair s.name s.keys) cfg.cliConfig.secrets))
        );
      in
      ''
        echo "[agenixManager] Writing secrets.nix -> /etc/agenix/secrets.nix"
        echo "[agenixManager] Writing CLI cache   -> /etc/agenix/agenix-manager-cache.json"
        echo "[agenixManager] Writing keys snapshot -> /etc/agenix/keys-snapshot.json"
        mkdir -p /etc/agenix
        cp ${secretsNixFile} /etc/agenix/secrets.nix
        cp ${cliConfigFile} /etc/agenix/agenix-manager-cache.json
        cp ${keysSnapshotFile} /etc/agenix/keys-snapshot.json
        chmod 644 /etc/agenix/agenix-manager-cache.json /etc/agenix/keys-snapshot.json
      ''
    );
    deps = lib.mkForce [ ];
  };

  # Preserve the CLI-modified manifest across rebuilds:
  #   - First boot:  copy from repo (no runtime file exists yet)
  #   - Subsequent:  keep whatever the CLI wrote (do NOT overwrite)
  # To force a fresh copy from the repo, delete /etc/agenix/secrets-manifest.json
  # and run `nix run .#activate`.
  system.activationScripts.agenixManagerSecretsManifestBootstrap = {
    deps = [ "agenixManagerSecretsNix" ];
    text = ''
      if [ ! -f /etc/agenix/secrets-manifest.json ]; then
        echo "[agenixManager] Bootstrapping secrets manifest -> /etc/agenix/secrets-manifest.json"
        install -m 644 ${./secrets/secrets-manifest.json} /etc/agenix/secrets-manifest.json
      fi
    '';
  };

  # ── Sensible Defaults ────────────────────────────────────────────────────

  my = {
    # Reverse proxy dashboard: Shows all enabled web services at localhost:8081
    # with a service dashboard. mkDefault so hosts can override port/addresses.
    # Override when: Host needs port 8081 for something else.
    services.proxy.enable = lib.mkDefault true;

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
        enable = lib.mkDefault false;
        acl.enable = lib.mkDefault true;

        authKeys = lib.mkDefault {
          tailscale-live-key = {
            description = "Temporary live environment key";
            tags = [ "tag:temp" ];
            ephemeral = true;
            reusable = true;
            preauthorized = false;
            recreateIfInvalid = "always";
          };
          nixos-machine-key = {
            description = "NixOS machine key";
            tags = [ "tag:nixos" ];
            reusable = true;
            ephemeral = false;
            preauthorized = true;
            recreateIfInvalid = "always";
          };
        };

        policy = {
          enable = lib.mkDefault true;

          tagOwners = lib.mkDefault {
            "tag:nixos" = [ "autogroup:admin" ];
            "tag:temp" = [ "tag:nixos" ];
          };

          interNodePorts = lib.mkDefault [ "tcp:22" "tcp:4567" "tcp:8000" "tcp:8080" ];

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
              users = [ "root" "autogroup:nonroot" flake.config.me.username ];
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

    # ZeroTier defaults: Secondary mesh VPN for dual-mesh fallback
    # Override when: Not using ZeroTier, or using a different network
    services.zerotier = {
      networks = lib.mkDefault [ "1c33c1ced07e2ece" ];
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

        # Per-host branch: each machine stays on its own branch for rollout gating
        # Override when: Single-branch workflow preferred
        branch = lib.mkDefault config.networking.hostName;

        # Merge master into the per-host branch after each sync
        # Override when: Not using per-host branches or manual merge preferred
        mergeUpstream = lib.mkDefault "master";

        # Push local commits on the per-host branch after each sync
        # Override when: Manual push workflow preferred
        autoPush = lib.mkDefault true;
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

  # Limit systemd-boot entries to prevent /boot from filling up
  # mkDefault so hosts can override (e.g., desktops needing more fallbacks)
  boot.loader.systemd-boot.configurationLimit = lib.mkDefault 10;

  # ZFS: Don't force-import root pool by default (safer)
  # Hosts that need it can set boot.zfs.forceImportRoot = true
  boot.zfs.forceImportRoot = lib.mkDefault false;

  # ── Environment ──────────────────────────────────────────────────────────
  # Base packages available on all hosts
  environment.systemPackages = with pkgs; [
    nix-template-selector # Interactive flake template selector
    github-actions-cleanup # GitHub Actions cleanup tool
  ]
  ++ lib.optionals config.services.xserver.enable [
    xclip # X11 clipboard utility
  ];

  # Additional packages are defined per-host or use environment.systemPackages directly

  # ── Assertions ───────────────────────────────────────────────────────────
  # Note: Profile mutual-exclusivity assertions live in profiles/system/default.nix
}
