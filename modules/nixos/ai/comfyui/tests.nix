{ config, lib, ... }:
let
  cfg = config.my.services.comfyui;
in
{
  assertions = [
    {
      assertion = !cfg.enable || cfg.port > 0;
      message = "my.services.comfyui.port must be a valid port number.";
    }
    {
      assertion = !cfg.enable || cfg.dataDir != "";
      message = "my.services.comfyui.dataDir must not be empty.";
    }
    {
      assertion = !cfg.enable || !cfg.enableManager || cfg.manager.url != "";
      message = "my.services.comfyui.enableManager requires a manager source (my.services.comfyui.manager.url).";
    }
    {
      assertion = !cfg.enable || !cfg.enableManager || (cfg.manager.rev == null) == (cfg.manager.sha256 == null);
      message = ''
        my.services.comfyui.manager: rev and sha256 must be set together.
        - both null     → builtins.fetchGit (convenience, impure)
        - both set      → pkgs.fetchgit (locked, pure) — values from `nix-prefetch-git <url> <rev>`
      '';
    }
    {
      assertion = !cfg.enable || lib.all (n: n.url != "") (lib.attrValues (lib.filterAttrs (_: n: n.enable) cfg.customNodes));
      message = "my.services.comfyui.customNodes: each enabled node must have a non-empty url.";
    }
    {
      assertion = !cfg.enable || lib.all
        (n: (n.rev == null) == (n.sha256 == null))
        (lib.attrValues (lib.filterAttrs (_: n: n.enable) cfg.customNodes));
      message = ''
        my.services.comfyui.customNodes: rev and sha256 must be set together.
        - both null     → builtins.fetchGit (convenience, impure)
        - both set      → pkgs.fetchgit (locked, pure) — values from `nix-prefetch-git <url> <rev>`
      '';
    }
    {
      assertion = !cfg.enable || lib.all (p: lib.hasAttr p (import ./catalog.nix)) cfg.presets;
      message = ''
        my.services.comfyui.presets: unknown catalog name(s):
        ${lib.concatStringsSep ", " (lib.filter (p: !lib.hasAttr p (import ./catalog.nix)) cfg.presets)}
        Valid names: ${lib.concatStringsSep ", " (lib.attrNames (import ./catalog.nix))}
      '';
    }
  ];
}
