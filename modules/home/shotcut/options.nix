{ lib, pkgs, ... }:

let
  inherit (lib) types;
in
{
  options.my.programs.shotcut = {
    enable = lib.mkEnableOption "Shotcut";

    package = lib.mkOption {
      type = types.package;
      default = pkgs.shotcut;
      defaultText = lib.literalExpression "pkgs.shotcut";
      description = ''
        The Shotcut package to use. Upstream ships a Qt6 + MLT build that does
        not pull in the KDE Frameworks, unlike `kdePackages.kdenlive`.
      '';
    };
  };
}
