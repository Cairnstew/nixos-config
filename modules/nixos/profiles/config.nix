{ lib, ... }:
{
  config = {
    my.profiles = lib.mkDefault { };
    my.homeProfiles = lib.mkDefault { };
  };
}
