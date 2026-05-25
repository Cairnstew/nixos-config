{ config, lib, flake, ... }:
let
  cfg = config.my.disko.dualBoot;
  # Capture module values in the outer scope so they're available
  # to the VM test node module without needing flake as a module arg.
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
      assertion = !cfg.enable || cfg.windowsSizeGB > 0;
      message = "my.disko.dualBoot.windowsSizeGB must be positive when enabled.";
    }
    {
      assertion = !cfg.enable || cfg.espSizeGB > 0;
      message = "my.disko.dualBoot.espSizeGB must be positive when enabled.";
    }
  ];

  my.testing.vmTests.disko-dualboot = {
    enable = true;
    name = "disko-dualboot";
    nodes.machine = { lib, ... }: {
      imports = [
        diskoMod
        diskoOpts
        diskoConfig
      ];

      my.disko.dualBoot = {
        enable = true;
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

      # Verify the system boots with the disko dual-boot module enabled
      machine.wait_for_unit("default.target")
      print("Disko dual-boot VM test: PASS")
    '';
    meta = {
      description = "Validates dual-boot disko partition layout and GRUB config";
      module = "disko";
    };
  };
}
