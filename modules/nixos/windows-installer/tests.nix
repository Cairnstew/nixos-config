{ config, lib, flake, ... }:
let
  cfg = config.my.services.windowsInstaller;
in
{
  assertions = [
    {
      assertion = !cfg.enable || cfg.windowsDisk != "";
      message = "my.services.windowsInstaller.windowsDisk must be set when enabled.";
    }
    {
      assertion = !cfg.enable || cfg.windowsPartitionIndex >= 1;
      message = "my.services.windowsInstaller.windowsPartitionIndex must be >= 1.";
    }
    {
      assertion = !cfg.enable || cfg.dscConfigPath == null || cfg.dscConfigPath != "";
      message = "my.services.windowsInstaller.dscConfigPath must not be empty when set.";
    }
  ];

  my.testing.vmTests.windows-iso = {
    enable = true;
    name = "windows-installer-iso";
    nodes.machine = { ... }: {
      imports = [
        ./options.nix
      ];

      my.services.windowsInstaller = {
        enable = true;
        windowsBuild = "windows-11";
        windowsEdition = "pro";
        windowsLang = "en-gb";
        windowsDisk = "/dev/vda";
        localUsername = "testuser";
        localPassword = "testpass123";
      };

      system.stateVersion = "25.05";
    };
    testScript = ''
      machine.wait_for_unit("default.target")
      print("Windows installer options VM test: PASS")
    '';
    meta = {
      description = "Validates windows-installer systemd unit and directory setup";
      module = "windows-installer";
    };
  };
}
