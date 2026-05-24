{ lib, ... }:
{
  options.my.services.cachix-push = {
    enable = lib.mkEnableOption "Cachix push service";

    cacheName = lib.mkOption {
      type = lib.types.str;
      description = "Name of the Cachix cache to push to";
    };

    tokenFile = lib.mkOption {
      type = lib.types.path;
      description = "Path to file containing the Cachix auth token (e.g. from agenix)";
    };

    paths = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Store paths to push. If empty, pushes the current system toplevel.";
    };

    onCalendar = lib.mkOption {
      type = lib.types.str;
      default = "weekly";
      description = "Systemd calendar expression for how often to push. See systemd.time(7).";
    };
  };
}
