{ config, lib, ... }:
let
  knownExtensions = import ./extensions.nix;
  knownExtensionNames = builtins.attrNames knownExtensions;

  cfg = config.my.programs.firefox;
in
{
  assertions = lib.mkIf cfg.enable [
    # L0: every extension name must be known (derived from extensions.nix)
    {
      assertion = builtins.all (name: builtins.elem name knownExtensionNames) cfg.extensions;
      message = ''
        Unknown Firefox extension(s): "${lib.concatStringsSep ", " (builtins.filter (name: !(builtins.elem name knownExtensionNames)) cfg.extensions)}".
        Add it to modules/home/firefox/extensions.nix with its guid and AMO shortId.
      '';
    }

    # L0: warn when no extensions are configured (allowed but unusual)
    {
      assertion = cfg.extensions != [ ];
      message = "Firefox is enabled but no extensions are configured. This is allowed but unusual.";
    }
  ];
}
