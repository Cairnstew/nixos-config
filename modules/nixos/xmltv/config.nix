{ config, lib, pkgs, ... }:
let
  cfg = config.my.services.xmltv;
  pkg = if cfg.package != null then cfg.package else pkgs.xmltv;
  inherit (lib) mkIf;

  configFile = "/var/lib/xmltv/tv_grab_uk_freeview.conf";

  configContent = if cfg.configure.region != null && cfg.configure.channels != [ ] then
    lib.concatStringsSep "\n" (
      [ "format=${cfg.configure.channelFormat}" ]
      ++ [ "region=${cfg.configure.region}" ]
      ++ [ "iconc=?w=160" ]
      ++ [ "iconp=?w=800" ]
      ++ map (ch: "channel=${ch}") cfg.configure.channels
    )
  else "";
in
{
  config = mkIf cfg.enable {
    environment.systemPackages = [ pkg ];

    systemd = {
      services = {
        xmltv-configure = mkIf (cfg.configure.region != null && cfg.configure.channels != [ ]) {
          description = "XMLTV EPG grabber config writer";
          before = [ "xmltv-grab.service" ];
          requiredBy = [ "xmltv-grab.service" ];

          serviceConfig = {
            Type = "oneshot";
            User = "root";
            StateDirectory = "xmltv";
            StateDirectoryMode = "0755";
          };

          script = ''
            mkdir -p "$(dirname '${configFile}')"
            cat > '${configFile}' << 'CONF'
${configContent}
CONF
            chmod 600 '${configFile}'
          '';
        };

        xmltv-configure-interactive = mkIf cfg.configure.enable {
          description = "XMLTV EPG grabber interactive configuration";
          after = [ "network-online.target" ];
          wants = [ "network-online.target" ];

          serviceConfig = {
            Type = "oneshot";
            User = "root";
            StateDirectory = "xmltv";
            StateDirectoryMode = "0755";
            ExecStart = "${pkg}/bin/${cfg.grabber} --configure";
            StandardInput = "tty";
            StandardOutput = "tty";
            StandardError = "tty";
          };
        };

        xmltv-grab = {
          description = "XMLTV EPG data grabber";
          after = [ "network-online.target" ];
          wants = [ "network-online.target" ];

          serviceConfig = {
            Type = "oneshot";
            User = "root";
            StateDirectory = "xmltv";
            StateDirectoryMode = "0755";
            ExecStart = "${pkg}/bin/${cfg.grabber} --config-file ${configFile} --output ${cfg.outputPath} --days ${toString cfg.days}${lib.optionalString (cfg.extraArgs != [ ]) " "}${lib.escapeShellArgs cfg.extraArgs}";
            Nice = 19;
            IOSchedulingClass = "idle";
            PrivateTmp = true;
            NoNewPrivileges = true;
            TimeoutSec = "3600";
          };
        };

        xmltv-serve = mkIf cfg.serveViaHttp {
          description = "XMLTV EPG HTTP server";
          wantedBy = [ "multi-user.target" ];
          after = [ "xmltv-grab.service" ];

          serviceConfig = {
            Type = "simple";
            User = "root";
            ExecStart = "${pkgs.python3}/bin/python3 -m http.server ${toString cfg.httpPort} --bind 127.0.0.1 --directory ${lib.dirOf cfg.outputPath}";
            Restart = "on-failure";
            RestartSec = "10s";
          };
        };
      };

      timers.xmltv-grab = {
        description = "XMLTV EPG data refresh timer";
        wantedBy = [ "timers.target" ];

        timerConfig = {
          OnCalendar = cfg.timerInterval;
          Persistent = true;
          RandomizedDelaySec = "30m";
        };
      };
    };
  };
}
