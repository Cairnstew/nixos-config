{ lib, pkgs, ... }:
let
  inherit (lib) mkEnableOption mkOption types;
  portSubmodule = types.submodule {
    options = {
      port = mkOption {
        type = types.port;
        description = "TCP/UDP port number.";
      };
      protocol = mkOption {
        type = types.enum [ "tcp" "udp" ];
        default = "udp";
        description = "Transport protocol. Game servers are usually UDP.";
      };
    };
  };
in
{
  options.my.services.game-servers = {
    enable = mkEnableOption "Steam/generic dedicated game servers via steamcmd";

    user = mkOption {
      type = types.str;
      default = "game-servers";
      description = "System user under which all game servers run.";
    };

    group = mkOption {
      type = types.str;
      default = "game-servers";
      description = "System group under which all game servers run.";
    };

    dataDir = mkOption {
      type = types.str;
      default = "/var/lib/game-servers";
      description = ''
        Base directory holding each server's install and save data.
        Each server's <literal>stateDir</literal> defaults to
        <literal>''${dataDir}/&lt;name&gt;</literal>.
        Point this at a large, fast disk (e.g. <literal>/mnt/data/game-servers</literal>).
      '';
    };

    steamcmd = mkOption {
      type = types.package;
      default = pkgs.steamcmd;
      defaultText = lib.literalExpression "pkgs.steamcmd";
      description = "steamcmd package used to install/update servers.";
    };

    steamRun = mkOption {
      type = types.package;
      default = pkgs.steam-run;
      defaultText = lib.literalExpression "pkgs.steam-run";
      description = ''
        FHS wrapper (steam-run) used to execute server binaries with their
        expected 32-bit/glibc runtime. Do not replace unless you know what
        you are doing.
      '';
    };

    servers = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          enable = mkOption {
            type = types.bool;
            default = true;
            description = "Whether to run and manage this server.";
          };

          appId = mkOption {
            type = types.str;
            description = ''
              Steam App ID of the dedicated server. Find it from the game's
              Steam store page or steamdb.info (e.g. 740 = CS2).
            '';
          };

          name = mkOption {
            type = types.str;
            default = "";
            description = "Human-readable display name. Defaults to the attribute name.";
          };

          startCommand = mkOption {
            type = types.str;
            description = ''
              Executable (relative to <literal>stateDir</literal>) to run to
              start the server, e.g. <literal>srcds_run</literal>.
            '';
          };

          args = mkOption {
            type = types.listOf types.str;
            default = [ ];
            example = [ "-game csgo" "-port 27015" ];
            description = "Extra arguments passed to <literal>startCommand</literal>.";
          };

          environment = mkOption {
            type = types.attrsOf types.str;
            default = { };
            example = { STEAM_APPID = "740"; };
            description = "Environment variables set for the server process.";
          };

          stateDir = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = ''
              Install/save directory. Defaults to
              <literal>''${my.services.game-servers.dataDir}/&lt;name&gt;</literal>.
            '';
          };

          autoUpdate = mkEnableOption "update (install) the server via steamcmd at every service start";

          validate = mkEnableOption "run steamcmd with the `validate` flag (full file verification)";

          branch = mkOption {
            type = types.nullOr types.str;
            default = null;
            example = "beta";
            description = "Steam depot beta branch to install, or null for the stable branch.";
          };

          login = {
            user = mkOption {
              type = types.str;
              default = "anonymous";
              description = "Steam username used by steamcmd. Most servers only need `anonymous`.";
            };
            passwordFile = mkOption {
              type = types.nullOr types.path;
              default = null;
              description = ''
                Path to a file containing the Steam password (e.g. an agenix
                secret). Only needed for games whose depots require login.
                Leave null for anonymous downloads.
              '';
            };
          };

          openFirewall = mkEnableOption "open this server's ports in the firewall";

          ports = mkOption {
            type = types.listOf portSubmodule;
            default = [ ];
            example = [
              { port = 27015; protocol = "udp"; }
              { port = 27015; protocol = "tcp"; }
            ];
            description = "Ports to open when <literal>openFirewall</literal> is enabled.";
          };

          nice = mkOption {
            type = types.int;
            default = -5;
            description = "Nice level for the server process.";
          };

          restart = mkOption {
            type = types.str;
            default = "on-failure";
            description = "systemd Restart policy for the server unit.";
          };

          restartSec = mkOption {
            type = types.str;
            default = "5s";
            description = "Delay between automatic restarts.";
          };

          timeoutStartSec = mkOption {
            type = types.str;
            default = "infinity";
            description = "systemd startup timeout. Server binaries can take a while to come up.";
          };

          after = mkOption {
            type = types.listOf types.str;
            default = [ ];
            description = "Additional units this server should start after.";
          };

          wants = mkOption {
            type = types.listOf types.str;
            default = [ ];
            description = "Additional units this server should pull in.";
          };

          extraExecStartPre = mkOption {
            type = types.listOf types.str;
            default = [ ];
            description = "Extra shell commands to run before the server starts (after the steamcmd update).";
          };

          extraServiceConfig = mkOption {
            type = types.attrs;
            default = { };
            description = ''
              Extra systemd <literal>serviceConfig</literal> attributes merged
              onto the server unit. Beware: steam-run uses bwrap, so strict
              sandboxing options (NoNewPrivileges, PrivateMounts, ...) will
              break it.
            '';
          };

          updateSchedule = mkOption {
            type = types.nullOr types.str;
            default = null;
            example = "daily";
            description = ''
              If set, run a steamcmd update on a systemd timer with this
              calendar spec and restart the server afterwards. Null disables
              the timer (update only happens on service start via autoUpdate).
            '';
          };

          monitoring = {
            enable = mkEnableOption "an A2S Prometheus exporter for this server";

            queryPort = mkOption {
              type = types.nullOr types.port;
              default = null;
              description = ''
                The server's A2S query port (game port + 1 for most Source
                games). Required when monitoring is enabled.
              '';
            };

            exporterPort = mkOption {
              type = types.port;
              default = 9841;
              description = "Metrics listen port for this server's exporter.";
            };
          };
        };
      });
      default = { };
      description = "Per-game dedicated server definitions.";
      example = {
        cs2 = {
          appId = "740";
          startCommand = "game/bin/linuxsteamrt64/cs2";
          args = [ "-dedicated" "-usercon" "-port 27015" ];
          ports = [
            { port = 27015; protocol = "udp"; }
            { port = 27015; protocol = "tcp"; }
            { port = 27016; protocol = "udp"; }
          ];
          openFirewall = true;
          monitoring = {
            enable = true;
            queryPort = 27015;
            exporterPort = 9841;
          };
        };
      };
    };

    monitoring = {
      enable = mkEnableOption "the A2S game-server Prometheus exporter bundle";

      exporter = mkOption {
        type = types.nullOr types.package;
        default = null;
        description = ''
          a2s-exporter package used for per-server monitoring instances.
          Defaults to the in-repo <literal>a2s-exporter</literal> package
          (<literal>flake.inputs.self.packages.&lt;system&gt;.a2s-exporter</literal>).
        '';
      };

      listenAddress = mkOption {
        type = types.str;
        default = "127.0.0.1";
        description = "Address game servers are queried on (the query port).";
      };
    };
  };
}
