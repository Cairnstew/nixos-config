{ lib, ... }:
let
  inherit (lib) mkEnableOption mkOption types;
in
{
  options.my.vm = {
    enable = mkEnableOption "per-host QEMU VM packages";

    hosts = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [ "laptop" "desktop" ];
      description = "Hostnames to build VMs for. Empty = all NixOS hosts.";
    };

    memory = mkOption {
      type = types.int;
      default = 2048;
      description = "Default VM memory in MB.";
    };

    cores = mkOption {
      type = types.int;
      default = 2;
      description = "Default number of CPU cores.";
    };

    diskSize = mkOption {
      type = types.int;
      default = 4096;
      description = "Default virtual disk size in MB.";
    };

    portForward = mkOption {
      type = types.attrsOf types.int;
      default = { };
      example = { host = 2222; guest = 22; };
      description = "Port forwards from host to VM guest. Each attr has `host` and `guest` ports.";
    };
  };
}
