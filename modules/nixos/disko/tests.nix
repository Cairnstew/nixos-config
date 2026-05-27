{ config, lib, flake, ... }:
let
  cfg = config.my.disko.dualBoot;
  diskoMod = flake.inputs.disko.nixosModules.default;
  selfMod = flake.inputs.self.nixosModules;
  diskoOpts = ./options.nix;
  diskoConfig = ./config.nix;
in
{
  assertions = [
    {
      assertion = !cfg.enable || cfg.disk != "";
      message = "my.disko.dualBoot.disk must not be empty when enabled.";
    }
    {
      assertion = !cfg.enable || cfg.mode == "fresh" || (cfg.mode == "useExisting" && cfg.nixosPartition != null);
      message = "my.disko.dualBoot.nixosPartition is required when mode = \"useExisting\".";
    }
    {
      assertion = !cfg.enable || cfg.mode != "fresh" || cfg.windowsSizeGB > 0;
      message = "my.disko.dualBoot.windowsSizeGB must be positive in fresh mode.";
    }
    {
      assertion = !cfg.enable || cfg.mode != "fresh" || cfg.espSizeGB > 0;
      message = "my.disko.dualBoot.espSizeGB must be positive in fresh mode.";
    }
  ];

  my.testing.vmTests.disko-dualboot = {
    enable = true;
    name = "disko-dualboot-fresh";
    nodes.machine = { lib, ... }: {
      imports = [
        diskoMod
        diskoOpts
        diskoConfig
      ];

      my.disko.dualBoot = {
        enable = true;
        mode = "fresh";
        disk = "/dev/vda";
        espSizeGB = 1;
        windowsSizeGB = 60;
      };

      boot.loader.grub.enable = true;
      boot.loader.grub.devices = [ "nodev" ];
      boot.loader.grub.efiSupport = true;
      boot.loader.efi.canTouchEfiVariables = true;

      system.stateVersion = "25.05";
    };
    testScript = ''
      start_all()
      machine.wait_for_unit("default.target")
      print("Disko dual-boot (fresh) VM test: PASS")
    '';
    meta = {
      description = "Validates fresh dual-boot disko partition layout and GRUB config";
      module = "disko";
    };
  };

  my.testing.vmTests.disko-dualboot-existing = {
    enable = true;
    name = "disko-dualboot-existing";
    nodes.machine = { lib, ... }: {
      imports = [
        diskoMod
        diskoOpts
        diskoConfig
      ];

      my.disko.dualBoot = {
        enable = true;
        mode = "useExisting";
        disk = "/dev/vda";
        nixosPartition = "/dev/vda3";
        espPartition = "/dev/vda1";

        detection = {
          windowsPartition = "/dev/vda2";
          windowsSize = "60G";
          windowsLabel = "Windows";
          espPartition = "/dev/vda1";
          disk = "/dev/vda";
          freeSpace = "200G";
        };
      };

      boot.loader.grub.enable = true;
      boot.loader.grub.devices = [ "nodev" ];
      boot.loader.grub.efiSupport = true;
      boot.loader.efi.canTouchEfiVariables = true;

      system.stateVersion = "25.05";
    };
    testScript = ''
      start_all()
      machine.wait_for_unit("default.target")
      print("Disko dual-boot (useExisting) VM test: PASS")
    '';
    meta = {
      description = "Validates useExisting dual-boot fileSystems and GRUB config";
      module = "disko";
    };
  };
}
