{ lib, ... }:
{
  options.my.programs._1password = {
    enable = lib.mkEnableOption "1Password desktop app and CLI integration" // {
      default = true;
    };
  };
}
