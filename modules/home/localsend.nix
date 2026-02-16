{ flake, config, lib, pkgs, ... }:

let
  cfg = config.my.programs.localsend;
  inherit (flake) inputs;
  inherit (inputs) self;
in
{
  options.my.programs.localsend = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable LocalSend";
    };

    autostart = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Start LocalSend automatically on login";
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = self.packages.${pkgs.stdenv.hostPlatform.system}.localsend or pkgs.localsend;
      description = "Package to install for LocalSend";
    };  

  };

  config = lib.mkIf cfg.enable {
    home.packages = [
      cfg.package
    ];
  };
}
