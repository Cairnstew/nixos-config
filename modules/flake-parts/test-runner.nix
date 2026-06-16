{ config, lib, ... }:
let
  inherit (lib) mkForce;
in
{
  perSystem = { system, ... }:
    let
      # For each NixOS host, build the test runner script if my.testing.enable = true
      buildable = lib.mapAttrsToList (hostName: nixosCfg:
        let
          probed = builtins.tryEval (nixosCfg.extendModules {
            modules = [
              {
                services.tailscale.enable = mkForce false;
                services.tailscale-manager.enable = mkForce false;
              }
            ];
          }).config;
        in
        if probed.success then
          let
            hostConfig = probed.value;
            hasTests = hostConfig.my.testing.enable or false;
          in
          lib.optionalAttrs hasTests {
            "${hostName}-tests" = hostConfig.system.build.my-test-runner;
          }
        else
          { }
      ) (lib.filterAttrs
        (_: cfg:
          let
            probed = builtins.tryEval (cfg.config.nixpkgs.hostPlatform.system);
          in
          probed.success && probed.value == system
        )
        config.flake.nixosConfigurations);
    in
    {
      packages = lib.foldl' lib.recursiveUpdate { } buildable;
    };
}
