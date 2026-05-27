{ config, lib, ... }: {
  perSystem = { pkgs, system, ... }: let
    minimalEval = import "${pkgs.path}/nixos" {
      configuration = { pkgs, lib, modulesPath, ... }: {
        imports = [
          (modulesPath + "/installer/cd-dvd/installation-cd-base.nix")
        ];

        networking.hostName = "minimal";
        nixpkgs.hostPlatform = system;
        system.stateVersion = "24.05";

        # User with password for local access
        users.users.minimal = {
          isNormalUser = true;
          initialPassword = "nixos";
          extraGroups = [ "wheel" ];
        };
        users.users.root.initialPassword = "nixos";
        security.sudo.wheelNeedsPassword = false;

        # SSH for remote access
        services.openssh = {
          enable = true;
          settings.PasswordAuthentication = true;
          settings.PermitRootLogin = "yes";
        };

        # Git + flakes
        programs.git.enable = true;
        nix.settings.experimental-features = [ "nix-command" "flakes" ];
        nix.settings.accept-flake-config = true;

        # Auto-clone the flake repo at boot
        systemd.services.clone-nix-config = {
          wantedBy = [ "multi-user.target" ];
          requires = [ "network-online.target" ];
          after = [ "network-online.target" ];
          path = [ pkgs.git ];
          serviceConfig.Type = "oneshot";
          serviceConfig.User = "minimal";
          script = ''
            if [[ ! -d /home/minimal/nixos-config ]]; then
              git clone https://github.com/Cairnstew/nixos-config.git /home/minimal/nixos-config
            fi
          '';
        };

        isoImage.makeEfiBootable = true;
        isoImage.makeUsbBootable = true;
      };
      inherit system;
    };

    isoImageDir = minimalEval.config.system.build.isoImage;
  in {
    packages.nixos-minimal = pkgs.runCommandLocal "nixos-minimal.iso" {
      inherit isoImageDir;
    } ''
      cp -L "$isoImageDir"/iso/*.iso "$out"
    '';
  };
}
