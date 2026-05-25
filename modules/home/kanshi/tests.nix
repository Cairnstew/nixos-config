{ config, lib, ... }:
let
  cfg = config.my.services.kanshi;
in
{
  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.settings != [ ];
        message = ''
          my.services.kanshi.settings must not be empty when enabled.
          Define at least one profile or output directive, e.g.:
            my.services.kanshi.settings = [
              { profile = {
                  name = "default";
                  outputs = [ { criteria = "eDP-1"; status = "enable"; } ];
                };
              }
            ];
        '';
      }
    ];
  };
}
