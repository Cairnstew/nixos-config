{ lib, ... }:
let
  inherit (lib) types;
in
{
  options.my.services.xmltv = {
    enable = lib.mkEnableOption "XMLTV EPG grabber service for UK Freeview TV listings";

    package = lib.mkOption {
      type = types.nullOr types.package;
      default = null;
      example = "pkgs.xmltv";
      description = "XMLTV package to use (default: pkgs.xmltv from overlay)";
    };

    grabber = lib.mkOption {
      type = types.str;
      default = "tv_grab_uk_freeview";
      description = "XMLTV grabber script to use";
    };

    outputPath = lib.mkOption {
      type = types.path;
      default = "/var/lib/xmltv/epg.xml";
      description = "Path where the XMLTV file will be written";
    };

    timerInterval = lib.mkOption {
      type = types.str;
      default = "daily";
      example = "6h";
      description = "How often to refresh EPG data (systemd timer format: OnCalendar= or systemd.time interval)";
    };

    days = lib.mkOption {
      type = types.int;
      default = 7;
      example = 14;
      description = "Number of days of EPG data to grab (max 7 for this grabber)";
    };

    serveViaHttp = lib.mkOption {
      type = types.bool;
      default = false;
      description = "Serve the XMLTV file via a simple HTTP server on localhost";
    };

    httpPort = lib.mkOption {
      type = types.port;
      default = 8889;
      description = "Port for the XMLTV HTTP server";
    };

    configure = {
      enable = lib.mkOption {
        type = types.bool;
        default = false;
        description = "Run grabber --configure on next service start (set to true once, then deploy, then set back to false)";
      };

      region = lib.mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "64257";
        description = "Freeview region ID (64257 = London). Run 'tv_grab_uk_freeview --configure' to discover yours.";
      };

      channelFormat = lib.mkOption {
        type = types.enum [ "number" "label" ];
        default = "number";
        description = "Channel ID format (number = Freeview channel number, label = internal ID)";
      };

      channels = lib.mkOption {
        type = types.listOf types.str;
        default = [ ];
        example = [ "101" "102" "103" "104" "105" ];
        description = "List of Freeview channel numbers to include in EPG";
      };
    };

    extraArgs = lib.mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Extra arguments to pass to the grabber";
    };
  };
}
