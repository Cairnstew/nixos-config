{ lib, ... }:
{
  imports = [
    ./system
    ./home
    ./tests.nix
  ];

  config = {
    my.profiles = lib.mkDefault { };
    my.homeProfiles = lib.mkDefault { };
  };
}
