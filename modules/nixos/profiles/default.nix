# modules/nixos/profiles/default.nix
# System and user profiles for easy host configuration
# See: ../README.md for documentation
{ lib, flake, ... }:
let
  inherit (flake.config.me) username;
in
{
  imports = [
    ./system
    ./home
  ];

  # Make profiles available at both locations for convenience
  options.profiles = lib.mkOption {
    type = lib.types.attrsOf lib.types.anything;
    default = { };
    description = "System profiles available to configurations.";
  };

  options.homeProfiles = lib.mkOption {
    type = lib.types.attrsOf lib.types.anything;
    default = { };
    description = "Home profiles available to configurations.";
  };

  config = {
    # mkDefault {} for my.profiles: Allows hosts to enable profiles easily
    # Override when: Defining profile options at the host level
    my.profiles = lib.mkDefault { };
    my.homeProfiles = lib.mkDefault { };
  };
}
