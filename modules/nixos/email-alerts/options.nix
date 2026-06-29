{ lib, flake, ... }:
let
  inherit (lib) mkEnableOption mkOption types;
in
{
  options.my.services.emailAlerts = {
    enable = mkEnableOption "Email alert sending via SMTP";

    smtp = {
      host = mkOption {
        type = types.str;
        default = "smtp.gmail.com";
        description = "SMTP server hostname.";
      };

      port = mkOption {
        type = types.port;
        default = 587;
        description = "SMTP server port.";
      };

      user = mkOption {
        type = types.str;
        default = flake.config.me.email;
        description = "SMTP username (usually the Gmail address).";
      };

      from = mkOption {
        type = types.str;
        default = flake.config.me.email;
        description = "From: address for sent alerts.";
      };
    };

    to = mkOption {
      type = types.listOf types.str;
      default = [ flake.config.me.email ];
      description = "Default recipient address(es) for alerts.";
    };

    secretName = mkOption {
      type = types.str;
      default = "alert-gmail";
      description = "Agenix secret name containing the Gmail app password.";
    };
  };
}
