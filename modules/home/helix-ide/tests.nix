{ config, lib, ... }:

let
  cfg = config.my.programs.helix-ide;
in
{
  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.programs.helix.enable;
        message = "helix-ide requires programs.helix to be enabled.";
      }
      {
        assertion = config.programs.zellij.enable;
        message = "helix-ide requires programs.zellij to be enabled.";
      }
      {
        assertion = !cfg.theme.enable || cfg.theme.name != "";
        message = "my.programs.helix-ide.theme.name must not be empty.";
      }
      {
        assertion = !cfg.theme.enable || (config.programs.helix.themes ? ${cfg.theme.palette.slug});
        message = "helix-ide theme: the generated theme was not installed.";
      }
      {
        assertion = !cfg.theme.enable || (cfg.theme.palette ? base0D && cfg.theme.palette ? base00);
        message = "helix-ide theme: the palette is missing base16 slots.";
      }
    ];
  };
}
