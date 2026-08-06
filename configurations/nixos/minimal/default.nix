{ flake, ... }: {
  imports = [
    ./configuration.nix
    ./hardware-configuration.nix
    ./disk-config.nix
    flake.inputs.self.nixosModules.common
  ];

  nixpkgs.hostPlatform = "x86_64-linux";
  networking.hostName = "minimal";
  # F17: add sshTarget so minimal is deployable via nixos-unified like other hosts (recon F17)
  nixos-unified.sshTarget = "seanc@minimal";

  my.profiles = {
    minimal.enable = true;
    development.enable = true;
    location.enable = true;
  };

  my.homeProfiles = {
    common.enable = true;
    minimal.enable = true;
  };

  my.system.location = {
    # enable = true — redundant: profile already sets via mkIf cfg.location.enable (M3)
    timeZone = "America/Chicago";
    latitude = 30.2672;
    longitude = -97.7431;
  };

  my.services.ssh.authorizedKeys = [ flake.config.me.sshKey ];
}
