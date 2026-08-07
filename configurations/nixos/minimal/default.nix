{ flake, ... }: {
  imports = [
    ./configuration.nix
    ./hardware-configuration.nix
    ./disk-config.nix
    flake.inputs.self.nixosModules.common
  ];

  networking.hostName = "minimal";
  nixos-unified.sshTarget = "seanc@minimal";

  my.profiles = {
    minimal.enable = true;
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

  # F12: authorizedKeys inherited from common.nix mkDefault (single source of truth)
}
