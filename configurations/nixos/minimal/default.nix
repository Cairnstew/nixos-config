{ flake, ... }: {
  imports = [
    ./configuration.nix
    ./hardware-configuration.nix
    flake.inputs.self.nixosModules.common
  ];

  nixpkgs.hostPlatform = "x86_64-linux";
  networking.hostName = "minimal";

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
    timeZone = "America/Chicago";
    latitude = 30.2672;
    longitude = -97.7431;
  };

  my.services.ssh.authorizedKeys = [ flake.config.me.sshKey ];

  my.ventoy.enable = true;
  my.ventoy.hostIso.enable = false;
}
