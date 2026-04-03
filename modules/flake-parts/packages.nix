{ config, lib, ... }: {
  perSystem = { system, ... }: {
    packages = lib.mapAttrs
      (hostName: nixosCfg:
        (nixosCfg.extendModules {
          modules = [
            { my.secrets.enable = false; }
          ];
        }).config.system.build.default
      )
      (lib.filterAttrs
        (_: cfg:
          let
            probed = builtins.tryEval (cfg.config.nixpkgs.hostPlatform.system);  # ← changed
          in
            probed.success && probed.value == system
        )
        config.flake.nixosConfigurations);
  };
}