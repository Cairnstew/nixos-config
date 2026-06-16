{ config, lib, inputs, ... }:
let
  cfg = config.my.vm;
  inherit (lib) mkIf;
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

      selectedHosts = if cfg.hosts == [ ] then matchingHosts else lib.filterAttrs (name: _: builtins.elem name cfg.hosts) matchingHosts;

      buildVm = hostName: nixosCfg: extraConfig:
        let
          probed = builtins.tryEval (
            (nixosCfg.extendModules {
              modules = [
                "${inputs.nixpkgs}/nixos/modules/virtualisation/qemu-vm.nix"
                ({ lib, ... }: {
                  virtualisation = {
                    memorySize = cfg.memory;
                    cores = cfg.cores;
                    diskSize = cfg.diskSize;
                  };
                  my.services.tailscale = {
                    enable = lib.mkForce false;
                    manager.enable = lib.mkForce false;
                  };
                })
                extraConfig
              ];
            }).config.system.build.vm
          );
        in
        if probed.success then probed.value else null;

      buildVmGraphical = hostName: nixosCfg:
        buildVm hostName nixosCfg ({ lib, ... }: { });

      buildVmHeadless = hostName: nixosCfg:
        buildVm hostName nixosCfg {
          virtualisation.graphics = false;
        };

      hostResults = builtins.map (hostName:
        let
          nixosCfg = selectedHosts.${hostName};
          graphical = buildVmGraphical hostName nixosCfg;
          headless = buildVmHeadless hostName nixosCfg;
        in
        lib.optionalAttrs (graphical != null) {
          "${hostName}-vm" = graphical;
          "${hostName}-vm-headless" = headless;
        }
      ) (builtins.attrNames selectedHosts);
    in
    {
      packages = mkIf cfg.enable (
        builtins.foldl' (acc: pkgSet:
          if pkgSet == { } then acc else lib.recursiveUpdate acc pkgSet
        ) { } hostResults
      );
    };
}
