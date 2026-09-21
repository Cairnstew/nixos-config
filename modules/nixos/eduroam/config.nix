# eduroam config — wires up NetworkManager ensureProfiles + agenix secret
{ config, lib, pkgs, ... }:
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
          autoconnect-priority = toString cfg.autoconnectPriority;
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

    # Bake the agenix password into the volatile keyfile at every boot.
    # Rationale: NM only consults the file-secret-agent on *system-initiated*
    # activation (auto-connect path). When the connection is activated later by
    # the user clicking the network in the GUI, the interactive agent
    # (nm-applet) serves the request instead and a password dialog appears —
    # exactly the "manual password injection after poweroff" symptom. Writing
    # the password straight into the generated keyfile (regenerated from the
    # template every boot, same root-only /run) makes the secret available on
    # every activation path, so NM never prompts. The file-secret-agent stays
    # as a fallback for the boot-time auto-connect.
    systemd.services."my-networking-eduroam-inject" = {
      description = "Inject the eduroam password into the NM keyfile at boot";
      after = [ "NetworkManager-ensure-profiles.service" ];
      requires = [ "NetworkManager-ensure-profiles.service" ];
      before = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      path = [ pkgs.python3 pkgs.networkmanager ];
      script = ''
        PROFILE=/run/NetworkManager/system-connections/eduroam.nmconnection
        SECRET=${config.age.secrets.${cfg.passwordSecret}.path}
        [ -f "$PROFILE" ] || exit 0
        [ -r "$SECRET" ] || exit 0
        python3 - "$PROFILE" "$SECRET" <<'PYEOF'
        import sys
        profile, secret = sys.argv[1], sys.argv[2]
        pw = open(secret).read().rstrip('\n')
        lines = open(profile).read().splitlines()
        # Drop any stale password= line and locate the [802-1x] header.
        out, idx_8021x = [], -1
        for line in lines:
            if line.startswith('[802-1x]'):
                idx_8021x = len(out)
            if line.startswith('password='):
                continue
            out.append(line)
        # Insert password right after the [802-1x] header.
        if idx_8021x >= 0:
            out.insert(idx_8021x + 1, 'password=' + pw)
        open(profile, 'w').write('\n'.join(out) + '\n')
        PYEOF
        nmcli connection reload
      '';
    };
  };
}
