{ lib, config, pkgs, ... }:

let
  cfg = config.my.services.udisks2;
in
{
  options.my.services.udisks2 = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable udisks2 (disk mounting service)";
    };
  };

  config = lib.mkIf cfg.enable {
    services.udisks2.enable = true;
  };
}
