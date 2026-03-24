{ config, lib, ... }: {
  perSystem = { system, ... }: {
    packages = lib.mapAttrs
      (hostName: nixosCfg: nixosCfg.config.system.build.default)
      (lib.filterAttrs
        (_: cfg: cfg.config.nixpkgs.hostPlatform.system or "" == system)
        config.flake.nixosConfigurations);
  };
}