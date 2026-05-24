{ lib, ... }:
{
  options.my.homeManager = {
    enable = lib.mkEnableOption "Home Manager NixOS integration" // { default = true; };

    extraModules = lib.mkOption {
      type = lib.types.listOf lib.types.unspecified;
      default = [ ];
      description = "Extra home-manager modules to import for this user.";
    };

    extraConfig = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = { };
      description = "Extra configuration to merge into the user's home config.";
    };
  };
}
