{ flake, config, lib, pkgs, ... }:

let
  cfg = config.my.tools.uup-converter;
  inherit (flake) inputs;
  inherit (inputs) self;
in
{
  options.my.tools.uup-converter = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable uup-converter";
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = self.packages.${pkgs.stdenv.hostPlatform.system}.uup-converter;
      description = "Package to install for uup-converter";
    };  

  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      cfg.package
    ];
  };
}
