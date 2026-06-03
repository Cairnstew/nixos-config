{ config, lib, inputs, ... }:
let
  # Collect ISO definitions from all NixOS host configurations.
  # Each host can set `my.live.isos.<name> = { ... }` in their config.
  hostIsos = builtins.foldl'
    (acc: hostName:
      let
        hostCfg = config.flake.nixosConfigurations.${hostName} or { };
        hostLive = hostCfg.config.my.live or { };
      in
      if hostLive ? isos then
        acc // hostLive.isos
      else
        acc
    )
    { }
    (builtins.attrNames (config.flake.nixosConfigurations or { }));

  # Preset names → nixpkgs installer CD module paths
  # nixpkgs refactored these paths in 2025:
  # installation-cd-graphical.nix → installation-cd-graphical-gnome.nix
  # installation-cd-graphical-kde.nix → removed (KDE only via calamares/combined)
  cdModulePaths = {
    minimal = "/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix";
    graphical = "/nixos/modules/installer/cd-dvd/installation-cd-graphical-gnome.nix";
    graphical-kde = "/nixos/modules/installer/cd-dvd/installation-cd-graphical-calamares-plasma6.nix";
    graphical-combined = "/nixos/modules/installer/cd-dvd/installation-cd-graphical-combined.nix";
  };

  # Merge ISOs from NixOS host configs and direct flake-parts config.
  # A "default" demo ISO is always available so users can immediately
  # run `nix build .#live-iso-default` without any host config.
  allIsos = hostIsos // config.live.isos // lib.mapAttrs
    (_: default: default)
    (lib.filterAttrs (name: _: !(hostIsos ? name || config.live.isos ? name))
      {
        default = {
          baseModule = "minimal";
          system = "x86_64-linux";
          extraModules = [ ];
          extraPackages = [ ];
          sshKeys = [ ];
          rootPassword = null;
          squashfsCompression = "gzip -Xcompression-level 1";
          kernelParams = [ ];
          enableSSH = false;
          enableFlakes = true;
          includeChannel = false;
          isoName = null;
          volumeID = null;
          extraContents = [ ];
          tailscale = { enable = false; };
        };
      }
    );

  # Build a single live ISO from a named configuration entry.
  mkIso = name: isoConfig:
    let
      basePath = "${inputs.nixpkgs}${cdModulePaths.${isoConfig.baseModule}}";

      isoSettings = {
        boot.kernelParams = isoConfig.kernelParams;

        boot.postBootCommands = lib.mkIf (isoConfig.tailscale.authKeyFile != null) ''
          echo "live-iso: copying tailscale auth key from ISO overlay..."
          mkdir -p "$(dirname ${isoConfig.tailscale.authKeyFile})"
          cp "/iso${isoConfig.tailscale.authKeyFile}" "${isoConfig.tailscale.authKeyFile}"
          chmod 600 "${isoConfig.tailscale.authKeyFile}"
        '';

        isoImage.squashfsCompression =
          if isoConfig.squashfsCompression != null
          then isoConfig.squashfsCompression
          else "xz -Xdict-size 100%";

        image.baseName = lib.mkIf (isoConfig.isoName != null)
          (lib.mkForce (lib.removeSuffix ".iso" isoConfig.isoName));

        isoImage.volumeID = lib.mkIf (isoConfig.volumeID != null) isoConfig.volumeID;

        services.openssh = lib.mkIf isoConfig.enableSSH {
          enable = true;
          settings.PermitRootLogin = "yes";
        };

        users.users.root = {
          openssh.authorizedKeys.keys = isoConfig.sshKeys;
          initialHashedPassword = lib.mkIf (isoConfig.rootPassword != null)
            (lib.mkForce isoConfig.rootPassword);
        };

        environment.systemPackages = isoConfig.extraPackages;

        nix.settings.experimental-features = lib.mkIf isoConfig.enableFlakes [
          "nix-command"
          "flakes"
        ];

        services.tailscale = lib.mkIf isoConfig.tailscale.enable {
          enable = true;
          openFirewall = true;
          extraUpFlags = [ "--accept-routes" ];
        };

        # Extra files placed at specific paths in the ISO
        isoImage.contents = isoConfig.extraContents;
      };

      tailscaleAutoconnect = { pkgs, ... }: lib.mkIf isoConfig.tailscale.enable {
        systemd.services.tailscale-autoconnect = {
          description = "Automatically connect Tailscale at boot";
          after = [ "network-online.target" "tailscale.service" ];
          wants = [ "network-online.target" ];
          wantedBy = [ "multi-user.target" ];
          serviceConfig.Type = "oneshot";
          script = ''
            set -euo pipefail
            echo "Attempting Tailscale login (no authkey — manual auth required)..."
            ${pkgs.tailscale}/bin/tailscale up --accept-routes
          '';
        };
      };

      channelMod = lib.optional isoConfig.includeChannel
        "${inputs.nixpkgs}/nixos/modules/installer/cd-dvd/channel.nix";
    in
    (inputs.nixpkgs.lib.nixosSystem {
      system = isoConfig.system;
      modules = [
        basePath
        isoSettings
        tailscaleAutoconnect
      ] ++ channelMod ++ isoConfig.extraModules;
    }).config.system.build.isoImage;
in
{
  config.perSystem = { system, ... }: {
    packages = lib.mapAttrs'
      (name: isoConfig:
        lib.nameValuePair "live-iso-${name}" (mkIso name isoConfig)
      )
      (lib.filterAttrs (_: isoConfig: isoConfig.system == system) allIsos);
  };
}
