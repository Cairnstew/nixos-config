{ lib, pkgs, ... }:

let
  inherit (lib) types;
in
{
  options.my.programs.losslesscut = {
    enable = lib.mkEnableOption "LosslessCut";

    package = lib.mkOption {
      type = types.package;
      default = pkgs.losslesscut-bin;
      defaultText = lib.literalExpression "pkgs.losslesscut-bin";
      description = ''
        The LosslessCut package to use. The default `losslesscut-bin` wraps the
        upstream prebuilt Electron app. `pkgs.losslesscut` builds from source
        against nixpkgs' Electron instead, which is far more expensive to build.
      '';
    };
  };
}
