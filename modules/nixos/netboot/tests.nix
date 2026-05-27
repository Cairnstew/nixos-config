{ config, lib, ... }:
let
  inherit (lib) mkIf;
  cfg = config.my.services.netboot;
in
{
  config = mkIf cfg.enable {
    assertions = [
      # ── Network configuration ──
      {
        assertion = cfg.serverAddress != "";
        message = "Netboot: serverAddress must not be empty.";
      }
      {
        assertion = cfg.interface != "";
        message = "Netboot: interface must not be empty.";
      }
      {
        assertion = cfg.subnetPrefix >= 8 && cfg.subnetPrefix <= 30;
        message = "Netboot: subnetPrefix must be between 8 and 30 (got ${toString cfg.subnetPrefix}).";
      }
      {
        assertion = cfg.dhcpRange != "";
        message = "Netboot: dhcpRange must not be empty.";
      }

      # ── Machine configuration ──
      {
        assertion = cfg.machines == { }
          || lib.all (m: m.macAddress != "") (lib.attrValues cfg.machines);
        message = "Netboot: All machines must have a non-empty macAddress.";
      }
      {
        assertion = cfg.machines == { }
          || lib.all (m: builtins.length m.stages > 0) (lib.attrValues cfg.machines);
        message = "Netboot: All machines must have at least one stage defined.";
      }
      {
        assertion = cfg.machines == { }
          || lib.all (m:
            lib.all (s: builtins.elem s [ "discover" "windows" "nixos" "done" ]) m.stages
          ) (lib.attrValues cfg.machines);
        message = "Netboot: Machine stages must be one of: windows, nixos, done.";
      }

      # ── Windows boot ──
      {
        assertion = !cfg.windows.enable || cfg.windows.bootDir != "";
        message = "Netboot: windows.bootDir must not be empty when windows.enable is true.";
      }

      # ── NixOS netboot ──
      {
        assertion = !cfg.nixos.enable || cfg.nixos.ipxeUrl != "";
        message = "Netboot: nixos.ipxeUrl must not be empty when nixos.enable is true.";
      }

      # ── dnsmasq coexistence check ──
      {
        assertion = !cfg.enable
          || !config.my.services.natShare.enable
          || config.my.services.natShare.lanInterface != cfg.interface
          || cfg.serverAddress == config.my.services.natShare.lanAddress;
        message = ''
          Netboot and natShare are both active on interface '${cfg.interface}'.
          netboot uses serverAddress ${cfg.serverAddress} but natShare uses
          LAN address ${config.my.services.natShare.lanAddress}.
          If they differ, dnsmasq's dhcp-range from both modules will conflict.
          Either:
          - Set netboot.serverAddress and netboot.dhcpRange to natShare's subnet
          - Use different interfaces for each service
          - Disable one of the services
        '';
      }

      # ── Stage/feature mismatch ──
      {
        assertion = cfg.machines == { }
          || !(builtins.any (m: builtins.elem "windows" m.stages) (lib.attrValues cfg.machines))
          || cfg.windows.enable;
        message = ''
          Netboot: One or more machines have a 'windows' stage but my.services.netboot.windows.enable is false.
          Either enable windows or remove the stage from the machine definition.
        '';
      }
      {
        assertion = cfg.machines == { }
          || !(builtins.any (m: builtins.elem "nixos" m.stages) (lib.attrValues cfg.machines))
          || cfg.nixos.enable;
        message = ''
          Netboot: One or more machines have a 'nixos' stage but my.services.netboot.nixos.enable is false.
          Either enable nixos or remove the stage from the machine definition.
        '';
      }

      # ── Windows unattended ──
      {
        assertion = cfg.machines == { }
          || lib.all (m:
            !m.windows.unattended.enable || m.windows.unattended.password != ""
          ) (lib.attrValues cfg.machines);
        message = ''
          Netboot: Machines with unattended Windows install must have a non-empty password.
        '';
      }
      {
        assertion = cfg.machines == { }
          || lib.all (m:
            !m.windows.unattended.enable || m.windows.unattended.computerName != ""
          ) (lib.attrValues cfg.machines);
        message = ''
          Netboot: Machines with unattended Windows install must have a computerName set.
        '';
      }

      # ── NixOS autoInstall ──
      {
        assertion = cfg.machines == { }
          || lib.all (m:
            !m.nixos.autoInstall.enable
            || m.nixos.autoInstall.diskoConfig != { }
            || builtins.elem "discover" m.stages
          ) (lib.attrValues cfg.machines);
        message = ''
          Netboot: Machines with autoInstall enabled must provide a non-empty diskoConfig,
          or use "discover" stage to provide one at runtime.
        '';
      }

      # ── Destructive operation warning ──
    ];
    warnings =
      let
        destructiveMachines = lib.filterAttrs (n: m: m.nixos.autoInstall.enable) cfg.machines;
      in
      lib.optional (destructiveMachines != { }) ''
        ╔══════════════════════════════════════════════════════════════╗
        ║  DESTRUCTIVE OPERATION — autoInstall will wipe the disk    ║
        ╚══════════════════════════════════════════════════════════════╝
        The following machine(s) have nixos.autoInstall enabled with
        a disko config.  This will DESTROY ALL DATA on the target
        disk(s) and create a fresh partition layout:

        ${lib.concatStringsSep "\n" (lib.mapAttrsToList (n: m: "  - ${n} (${m.macAddress})") destructiveMachines)}

        Back up anything important before PXE-booting these machines.
      '';
  };
}
