{ lib, ... }:
let
  inherit (lib) mkEnableOption mkOption types;
in
{
  options.my.testing = {
    enable = mkEnableOption "centralized test runner that executes all module smoke tests and health checks";

    categories = mkOption {
      type = types.listOf (types.enum [ "smoke" "health" ]);
      default = [ "smoke" "health" ];
      description = "Which test categories to include. `smoke` runs *-smoke-test services, `health` runs *-health-check services.";
    };

    failHard = mkOption {
      type = types.bool;
      default = false;
      description = "Stop on the first test failure instead of continuing to run remaining tests.";
    };

    startAtBoot = mkOption {
      type = types.bool;
      default = false;
      description = "Run tests automatically during system boot (adds wantedBy = multi-user.target).";
    };
  };
}
