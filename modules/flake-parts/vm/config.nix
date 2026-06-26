{ config, lib, inputs, ... }:
let
  flakeCfg = config.my.vm; # flake-level options (hosts filter)
  inherit (lib) mkIf mkForce;
in
{
  perSystem = { system, ... }:
    let
      matchingHosts = lib.filterAttrs
        (_: nixosCfg:
          let
            probed = builtins.tryEval (nixosCfg.config.nixpkgs.hostPlatform.system);
          in
          probed.success && probed.value == system
        )
        config.flake.nixosConfigurations;

      # Hosts where my.vm.enable = true (optionally filtered by flakeCfg.hosts)
      enabledHosts = lib.filterAttrs
        (name: nixosCfg:
          let
            hostCfg = nixosCfg.config.my.vm or { };
            probedEnable = builtins.tryEval (hostCfg.enable or false);
            enabled = if probedEnable.success then probedEnable.value else false;
            inList = flakeCfg.hosts == [ ] || builtins.elem name flakeCfg.hosts;
          in
          enabled && inList
        )
        matchingHosts;

      buildVm = hostName: nixosCfg: hostCfg: variantExtra:
        let
          probed = builtins.tryEval (
            (nixosCfg.extendModules {
              modules = [
                "${inputs.nixpkgs}/nixos/modules/virtualisation/qemu-vm.nix"
                ({ lib, ... }: {
                  virtualisation = {
                    memorySize = hostCfg.memory;
                    cores = hostCfg.cores;
                    diskSize = hostCfg.diskSize;
                  };
                  my.services.tailscale = {
                    enable = lib.mkForce false;
                    manager.enable = lib.mkForce false;
                  };
                })
                hostCfg.extraConfig
                variantExtra
              ];
            }).config.system.build.vm
          );
        in
        if probed.success then probed.value else null;

      hostResults = lib.mapAttrsToList
        (hostName: nixosCfg:
          let
            hostCfg = nixosCfg.config.my.vm;
            graphical = buildVm hostName nixosCfg hostCfg ({ lib, ... }: { });
            headless = buildVm hostName nixosCfg hostCfg {
              virtualisation.graphics = false;
            };
          in
          lib.optionalAttrs (graphical != null) {
            "${hostName}-vm" = graphical;
            "${hostName}-vm-headless" = headless;
          }
        )
        enabledHosts;
    in
    {
      packages = builtins.foldl'
        (acc: pkgSet:
          if pkgSet == { } then acc else lib.recursiveUpdate acc pkgSet
        )
        { }
        hostResults;
    };
}
