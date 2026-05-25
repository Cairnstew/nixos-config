{ lib, ... }:

let
  inherit (lib) mkEnableOption mkOption types;
in
{
  options.my.testing = {
    vmTest.enable = mkEnableOption "VM integration tests via runNixOSTest";

    vmTests = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          enable = mkEnableOption "this VM test definition";
          name = mkOption {
            type = types.str;
            default = "";
            description = "Override name sent to runNixOSTest. Defaults to the attr key.";
          };
          nodes = mkOption {
            type = types.attrsOf types.raw;
            default = {};
            description = "NixOS node definitions passed to runNixOSTest.";
          };
          testScript = mkOption {
            type = types.str;
            default = ''
              machine.wait_for_unit("default.target");
            '';
            description = "Python test script for runNixOSTest.";
          };
          meta = mkOption {
            type = types.attrsOf types.raw;
            default = {};
            description = "Arbitrary metadata (hostname, module origin, etc.).";
          };
        };
      });
      default = {};
      internal = true;
      description = ''
        Registry of VM test specs. Set by module tests.nix files and host configs.
        Consumed by the flake-parts vm-test module to generate perSystem.checks.
      '';
    };
  };
}
