{ config, lib, flake, ... }:
let
  cfg = config.my.services.dscnix;
in
{
  assertions = [
    {
      assertion = !cfg.enable || (cfg.configurationName != "");
      message = "my.services.dscnix.configurationName must not be empty when dscnix is enabled.";
    }
  ];

  my.testing.vmTests.dscnix-yaml = {
    enable = true;
    name = "dscnix-yaml-validation";
    nodes.machine = { ... }: {
      # Provide flake via _module.args so imported modules can access it
      _module.args.flake = flake;
      imports = [
        ./options.nix
        ./config.nix
      ];

      my.services.dscnix = {
        enable = true;
        configurationName = "TestConfig";
        optionalFeatures = {
          "Microsoft-Windows-Subsystem-Linux" = { state = "Installed"; };
        };
        registry = {
          "TestKey" = {
            keyPath = "HKLM\\SOFTWARE\\Test";
            valueName = "TestValue";
            valueData = { DWord = 1; };
          };
        };
      };

      system.stateVersion = "25.05";
    };
    testScript = ''
      machine.wait_for_unit("default.target")
      # Verify YAML file was generated and contains expected content
      machine.succeed("test -f /etc/dscnix/desktop.yaml")
      machine.succeed("grep -q 'TestConfig' /etc/dscnix/desktop.yaml")
      machine.succeed("grep -q 'dscnix' /etc/dscnix/desktop.yaml")
      print("DSCnix YAML validation: PASS")
    '';
    meta = {
      description = "Validates DSC v3 YAML generation and format";
      module = "dscnix";
    };
  };
}
