{ config, lib, ... }:

let
  inherit (lib) mkOption types;

  # Collect all enabled VM test specs from all NixOS configurations.
  # Wraps tryEval so a single broken eval doesn't sink the entire flake check.
  collectVmTestSpecs = nixosConfigs:
    let
      allSpecs = lib.foldl (acc: cfg:
        let
          probed = builtins.tryEval cfg.config.my.testing.vmTests;
          tests = if probed.success then probed.value else { };
        in
        acc // (lib.filterAttrs (_: spec: spec.enable or false) tests)
      ) { } (builtins.attrValues nixosConfigs);
    in
      allSpecs;

  checkPrefix = "vm-test-";
in
{
  perSystem = { system, pkgs, ... }:
    let
      nixosConfigurations = config.flake.nixosConfigurations or { };
      specs = collectVmTestSpecs nixosConfigurations;

      checks = lib.mapAttrs (name: spec:
        pkgs.testers.runNixOSTest {
          name = if spec.name != "" then spec.name else name;
          nodes = spec.nodes or { };
          testScript = spec.testScript or ''
            machine.wait_for_unit("default.target");
          '';
        }
      ) specs;
    in
    {
      checks = lib.mapAttrs' (name: drv: {
        name = "${checkPrefix}${name}";
        value = drv;
      }) checks;
    };
}
