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
          hostPlatform = "x86_64-linux";
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
          tailscale = { enable = false; authKeyFile = null; authKeyEncryptedSource = null; };
        };
      }
    );

  # Build a single live ISO from a named configuration entry.
  mkIso = name: isoConfig:
    let
      basePath = "${inputs.nixpkgs}${cdModulePaths.${isoConfig.baseModule}}";

      isoSettings = {
        boot.kernelParams = isoConfig.kernelParams;

        boot.postBootCommands =
          if isoConfig.tailscale.authKeyEncryptedSource or null != null then ''
            echo "live-iso: copying encrypted secrets from ISO overlay..."
            mkdir -p /var/lib/tailscale
            cp /iso/var/lib/tailscale/tailscale-live-key.age /var/lib/tailscale/tailscale-live-key.age
            cp /iso/var/lib/tailscale/live-iso-ssh-key /var/lib/tailscale/live-iso-ssh-key
            chmod 600 /var/lib/tailscale/tailscale-live-key.age /var/lib/tailscale/live-iso-ssh-key
          ''
          else if isoConfig.tailscale.authKeyFile or null != null then ''
            echo "live-iso: copying tailscale auth key from ISO overlay..."
            mkdir -p "$(dirname ${isoConfig.tailscale.authKeyFile})"
            cp "/iso${isoConfig.tailscale.authKeyFile}" "${isoConfig.tailscale.authKeyFile}"
            chmod 600 "${isoConfig.tailscale.authKeyFile}"
          ''
          else "";

        isoImage.squashfsCompression =
          if isoConfig.squashfsCompression != null
          then isoConfig.squashfsCompression
          else "xz -Xdict-size 100%";

        image.baseName = lib.mkIf (isoConfig.isoName != null)
          (lib.mkForce (lib.removeSuffix ".iso" isoConfig.isoName));

        isoImage.volumeID = lib.mkIf (isoConfig.volumeID != null) isoConfig.volumeID;

        services.openssh = lib.mkIf isoConfig.enableSSH {
          enable = true;
          settings = {
            PermitRootLogin = "yes";
            PermitEmptyPasswords = "yes";
          };
        };

        users.users.root = {
          openssh.authorizedKeys.keys = isoConfig.sshKeys;
          initialHashedPassword = lib.mkIf (isoConfig.rootPassword != null)
            (lib.mkForce isoConfig.rootPassword);
        };

        users.users.nixos.openssh.authorizedKeys.keys = isoConfig.sshKeys;

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
        isoImage.contents = isoConfig.extraContents
          ++ lib.optional (isoConfig.tailscale.authKeyEncryptedSource or null != null) {
          source = isoConfig.tailscale.authKeyEncryptedSource;
          target = "/var/lib/tailscale/tailscale-live-key.age";
        };
      };

      tailscaleAutoconnect = { pkgs, ... }: lib.mkIf isoConfig.tailscale.enable (
        let
          authKeyFile = isoConfig.tailscale.authKeyFile or null;
        in
        {
          systemd.services.tailscale-autoconnect = {
            description = "Automatically connect Tailscale at boot";
            after = [ "network-online.target" "tailscale.service" "tailscale-decrypt-secrets.service" ];
            wants = [ "network-online.target" ];
            requires = [ "tailscale-decrypt-secrets.service" ];
            wantedBy = [ "multi-user.target" ];
            serviceConfig.Type = "oneshot";
            script = ''
              set -euo pipefail
              echo "Attempting Tailscale login..."
              ${if authKeyFile != null then ''
                if [ -f "${authKeyFile}" ]; then
                  ${pkgs.tailscale}/bin/tailscale up --accept-routes --authkey "$(cat ${authKeyFile})"
                else
                  echo "Auth key file not found at ${authKeyFile} — falling back to manual auth"
                  ${pkgs.tailscale}/bin/tailscale up --accept-routes
                fi
              '' else ''
                ${pkgs.tailscale}/bin/tailscale up --accept-routes
              ''}
            '';
          };
        }
      );

      tailscaleDecryptSecrets = { pkgs, ... }: lib.mkIf (isoConfig.tailscale.authKeyEncryptedSource or null != null) {
        environment.systemPackages = [ pkgs.age ];
        systemd.services.tailscale-decrypt-secrets = {
          description = "Decrypt ISO secrets using embedded age key";
          after = [ "local-fs.target" ];
          before = [ "tailscale-autoconnect.service" ];
          requiredBy = [ "tailscale-autoconnect.service" ];
          wantedBy = [ "multi-user.target" ];
          serviceConfig.Type = "oneshot";
          script = ''
            set -euo pipefail
            echo "live-iso: decrypting tailscale auth key..."
            mkdir -p "$(dirname ${isoConfig.tailscale.authKeyFile})"
            ${pkgs.age}/bin/age -d \
              -i /var/lib/tailscale/live-iso-ssh-key \
              -o ${isoConfig.tailscale.authKeyFile} \
              /var/lib/tailscale/tailscale-live-key.age
            chmod 600 ${isoConfig.tailscale.authKeyFile}
          '';
        };
      };

      channelMod = lib.optional isoConfig.includeChannel
        "${inputs.nixpkgs}/nixos/modules/installer/cd-dvd/channel.nix";
    in
    (inputs.nixpkgs.lib.nixosSystem {
      modules = [
        { nixpkgs.hostPlatform = isoConfig.hostPlatform; }
        basePath
        isoSettings
        tailscaleAutoconnect
        tailscaleDecryptSecrets
      ] ++ channelMod ++ isoConfig.extraModules;
    }).config.system.build.isoImage;
in
{
  config.perSystem = { system, ... }: {
    packages = lib.mapAttrs'
      (name: isoConfig:
        lib.nameValuePair "live-iso-${name}" (mkIso name isoConfig)
      )
      (lib.filterAttrs (_: isoConfig: isoConfig.hostPlatform == system) allIsos);
  };
}
