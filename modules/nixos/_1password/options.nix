{ config, lib, ... }:
{
  options.my.programs._1password = {
    enable = lib.mkEnableOption "1Password CLI integration" // {
      default = true;
    };

    gui.enable = lib.mkEnableOption "the 1Password desktop app and SSH agent" // {
      default = config.my.profiles.workstation.enable;
      defaultText = lib.literalExpression "config.my.profiles.workstation.enable";
    };
  };
}
