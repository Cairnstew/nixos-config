# eduroam option declarations
{ lib, ... }:
{
  options.my.networking.eduroam = {
    enable = lib.mkEnableOption "eduroam WiFi (WPA2-Enterprise) profile via NetworkManager";

    identity = lib.mkOption {
      type = lib.types.str;
      example = "2012345@gcu.ac.uk";
      description = "EAP identity (typically your student/staff email on the eduroam realm).";
    };

    passwordSecret = lib.mkOption {
      type = lib.types.str;
      default = "eduroam-password";
      description = "Name of the agenix secret containing the eduroam password.";
    };

    caCert = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      example = "/etc/ssl/certs/eduroam-ca.pem";
      description = "Path to the CA certificate for the RADIUS server. Null = use system CA bundle.";
    };

    interface = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "wlp170s0";
      description = "WiFi interface name. Null = let NetworkManager auto-detect.";
    };

    eap = lib.mkOption {
      type = lib.types.enum [ "peap" "tls" "ttls" "pwd" ];
      default = "peap";
      description = "EAP method. Most UK eduroam implementations use PEAP.";
    };

    phase2 = lib.mkOption {
      type = lib.types.enum [ "mschapv2" "gtc" "md5" ];
      default = "mschapv2";
      description = "Phase 2 (inner) authentication method. PEAP typically uses MSCHAPv2.";
    };

    domain = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "gcu.ac.uk";
      description = "Domain suffix match for the RADIUS server certificate. Null = skip domain matching.";
    };

    pmf = lib.mkOption {
      type = lib.types.int;
      default = 1;
      description = "Protected Management Frames (802.11w). 0=disabled, 1=optional, 2=required.";
    };

    autoconnectPriority = lib.mkOption {
      type = lib.types.int;
      default = 100;
      description = ''
        NetworkManager autoconnect-priority for the eduroam profile. Higher
        values win when several autoconnect=yes networks are in range, which
        prevents NM from silently joining an open/guest network (e.g. "WiFi
        Guest") instead of eduroam after a reboot. Default 100 so eduroam is
        preferred whenever it is visible.
      '';
    };
  };
}
