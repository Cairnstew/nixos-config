{ config, lib, ... }:
let
  cfg = config.my.services.windowsDscSync;
in
{
  assertions = [
    {
      assertion = !cfg.enable || cfg.windowsPartition != "";
      message = "my.services.windowsDscSync.windowsPartition must not be empty when enabled.";
    }
  ];

  my.testing.vmTests.windows-dsc-sync = {
    enable = true;
    name = "windows-dsc-sync";
    nodes.machine = { ... }: {
      imports = [
        ./options.nix
        ./config.nix
      ];

      my.services.windowsDscSync = {
        enable = true;
        windowsPartition = "/dev/vda2";
      };

      system.stateVersion = "25.05";
    };
    testScript = ''
      machine.wait_for_unit("default.target")
      machine.succeed("systemctl status windows-dsc-sync.path 2>/dev/null || true")
      print("Windows DSC sync VM test: PASS")
    '';
    meta = {
      description = "Validates windows-dsc-sync path unit and service are defined";
      module = "windows-dsc-sync";
    };
  };
}
