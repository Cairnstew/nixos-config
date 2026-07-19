{ lib, ... }:
{
  options.my.deploy = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable the deploy ISO with embedded tailscale auth key and age private key.";
    };
  };
}
