{ lib, ... }:
let
  inherit (lib) mkEnableOption mkOption types;
in
{
  options.my.services.hedgedoc = {
    enable = mkEnableOption "HedgeDoc collaborative markdown editor";

    domain = mkOption {
      type = types.str;
      default = "pad.srid.ca";
      description = "Domain for the HedgeDoc instance.";
    };

    port = mkOption {
      type = types.port;
      default = 9112;
      description = "Local port for HedgeDoc.";
    };

    allowAnonymous = mkOption {
      type = types.bool;
      default = false;
      description = "Allow anonymous users to create notes.";
    };
  };
}
