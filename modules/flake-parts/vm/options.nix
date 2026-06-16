{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.my.vm = {
    hosts = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [ "desktop" ];
      description = ''
        Hostnames to build VM packages for.
        Empty = all hosts with my.vm.enable = true.
        Non-empty = only the listed hosts (must also have my.vm.enable = true).
      '';
    };
  };
}
