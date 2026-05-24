{ lib, ... }:
{
  options.my.services.ssh = {
    enable = lib.mkEnableOption "SSH daemon with auto-generated root key";

    authorizedKeys = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "SSH public keys authorized for root login.";
    };
  };
}
