{ lib, ... }:
let
  inherit (lib) mkEnableOption mkOption types;
in
{
  options.my.vm = {
    enable = mkEnableOption "QEMU VM build for this host";

    memory = mkOption {
      type = types.int;
      default = 2048;
      description = "VM memory in MB.";
    };

    cores = mkOption {
      type = types.int;
      default = 2;
      description = "Number of CPU cores for the VM.";
    };

    diskSize = mkOption {
      type = types.int;
      default = 4096;
      description = "Virtual disk size in MB.";
    };

    extraConfig = mkOption {
      type = types.raw;
      default = { };
      example = {
        services.openssh.enable = true;
        networking.firewall.enable = false;
      };
      description = ''
        NixOS module fragment merged into this host's VM build only.
        Accepts an attrset, a function ({ config, pkgs, lib, ... }), or a path.
        Use to override hardware-specific options, disable services, or add
        packages that should only exist in the VM variant.
      '';
    };
  };
}
