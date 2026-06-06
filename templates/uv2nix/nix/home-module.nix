{ config, lib, pkgs, ... }:

let
  cfg = config.programs.uv2nix-template;
in

{

  options.programs.uv2nix-template = {
    enable = lib.mkEnableOption "uv2nix-template home-manager integration";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.uv2nix-template;
      defaultText = lib.literalExpression "pkgs.uv2nix-template";
      description = "Package to add to the user session";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ cfg.package ];
  };

}
