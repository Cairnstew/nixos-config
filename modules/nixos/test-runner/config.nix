{ config, lib, pkgs, ... }:
let
  cfg = config.my.testing;
  inherit (lib) mkIf;

  # Build a suffix list from the selected categories
  categorySuffixes = builtins.map
    (c: if c == "smoke" then "-smoke-test" else "-health-check")
    cfg.categories;

  # Discover all systemd services matching the selected categories
  allServices = builtins.attrNames config.systemd.services;
  isTestService = name:
    let
      suffixMatch = builtins.any (suffix: lib.hasSuffix suffix name) categorySuffixes;
    in
    suffixMatch && name != "my-test-runner";
  targetServices = builtins.filter isTestService allServices;

  # Generate a standalone test runner script
  testScript = pkgs.writeShellScript "my-test-runner" ''
    set -euo pipefail
    FAILED=0
    TOTAL=0
    PASSED=0
    echo "=== My Test Runner ==="
    echo "Categories: ${builtins.concatStringsSep ", " cfg.categories}"
    echo "Discovered: ${builtins.toString (builtins.length targetServices)} test services"
    echo ""

    ${lib.concatMapStringsSep "\n" (svc: ''
      TOTAL=$((TOTAL + 1))
      printf "--- [%s/%s] %s ---\n" "$TOTAL" "${builtins.toString (builtins.length targetServices)}" "${svc}"
      if systemctl restart "${svc}" 2>&1; then
        echo "PASS: ${svc}"
        PASSED=$((PASSED + 1))
      else
        echo "FAIL: ${svc}"
        FAILED=$((FAILED + 1))
        ${if cfg.failHard then "exit 1" else ""}
      fi
      echo ""
    '') targetServices}

    echo "=== Results: $TOTAL total, $PASSED passed, $FAILED failed ==="
    exit $FAILED
  '';
in
{
  systemd.services.my-test-runner = mkIf cfg.enable {
    description = "My Test Runner — execute all module smoke tests and health checks";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = testScript;
    };

    wantedBy = mkIf cfg.startAtBoot [ "multi-user.target" ];
  };

  # Expose as a buildable derivation so CI/CD tools can fetch it via
  # `nix build .#nixosConfigurations.<host>.config.system.build.my-test-runner`
  system.build.my-test-runner = mkIf cfg.enable testScript;
}
