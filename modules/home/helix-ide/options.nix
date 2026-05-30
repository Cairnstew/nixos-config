{ lib, ... }:
{
  options.my.programs.helix-ide = {
    enable = lib.mkEnableOption "Helix editor + Zellij IDE environment";
  };
}
