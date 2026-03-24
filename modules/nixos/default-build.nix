{ lib, config, ... }: {
  options.my.build.default = lib.mkOption {
    type = lib.types.str;               # e.g. "images.iso" or "tarballBuilder"
    default = "images.iso";             # sensible default for normal NixOS hosts
    example = "tarballBuilder";
    description = ''
      Attribute path under `config.system.build` that should be the default
      build artifact for this host (used by `nix build .#hostname`).
    '';
  };

  # This is the magic: we expose the chosen derivation as system.build.default
  config = {
    system.build.default =
      let
        path = lib.splitString "." config.my.build.default;
        drv = lib.attrByPath path null config.system.build;
      in
        if drv == null then
          # fallback so you don't get a hard error on misconfiguration
          config.system.build.toplevel
        else
          drv;
  };
}