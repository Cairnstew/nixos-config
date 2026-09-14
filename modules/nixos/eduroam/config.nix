# eduroam config — wires up NetworkManager ensureProfiles + agenix secret
{ config, lib, ... }:
let
  cfg = config.my.networking.eduroam;
  hasSecret = config.age.secrets ? "${cfg.passwordSecret}";
in
{
  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.networking.networkmanager.enable;
        message = "my.networking.eduroam requires networking.networkmanager.enable = true";
      }
      {
        assertion = hasSecret;
        message = ''
          my.networking.eduroam.passwordSecret is "${cfg.passwordSecret}" but
          no matching age.secrets entry was found. Add it to the agenix manifest
          and create the .age file, or change passwordSecret to an existing name.
        '';
      }
    ];

    networking.networkmanager.ensureProfiles.profiles = {
      eduroam = {
        connection = {
          id = "eduroam";
          type = "wifi";
        } // lib.optionalAttrs (cfg.interface != null) {
          interface-name = cfg.interface;
        };

        wifi = {
          mode = "infrastructure";
          ssid = "eduroam";
        };

        wifi-security = {
          key-mgmt = "wpa-eap";
          pmf = toString cfg.pmf;
        };

        "802-1x" = {
          eap = cfg.eap;
          identity = cfg.identity;
          phase2-auth = cfg.phase2;
        } // lib.optionalAttrs (cfg.caCert != null) {
          ca-cert = toString cfg.caCert;
        } // lib.optionalAttrs (cfg.domain != null) {
          domain-suffix-match = cfg.domain;
        };

        ipv4.method = "auto";
        ipv6.method = "auto";
      };
    };

    # Inject the eduroam password from the agenix secret into the NM profile.
    # nm-file-secret-agent reads the file at connection time — the plaintext
    # never touches the Nix store or /etc/NetworkManager.
    networking.networkmanager.ensureProfiles.secrets.entries = [{
      matchId = "eduroam";
      matchSetting = "802-1x";
      key = "password";
      file = config.age.secrets.${cfg.passwordSecret}.path;
    }];
  };
}
