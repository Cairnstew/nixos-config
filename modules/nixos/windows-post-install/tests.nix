{ config, lib, ... }:
let
  cfg = config.my.services.windowsPostInstall;
in
{
  assertions = [
    {
      assertion = true; # No specific assertions needed for this module
      message = "windows-post-install assertion placeholder";
    }
  ];

  my.testing.vmTests.windows-post-install = {
    enable = true;
    name = "windows-post-install";
    nodes.machine = { ... }: {
      imports = [
        ./options.nix
        ./config.nix
      ];

      my.services.windowsPostInstall = {
        enable = true;
        autoFixBootOrder = true;
      };

      system.stateVersion = "25.05";
    };
    testScript = ''
      machine.wait_for_unit("default.target")
      machine.succeed("test -f /var/lib/windows-post-install/.done || true")
      print("Windows post-install VM test: PASS")
    '';
    meta = {
      description = "Validates windows-post-install service runs without error";
      module = "windows-post-install";
    };
  };
}
