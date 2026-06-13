{ lib, pkgs, config, flake, ... }:
let
  format = pkgs.formats.hocon { };
in
{
  options.my.services.suwayomi = {
    enable = lib.mkEnableOption "Suwayomi manga reader server";

    package = lib.mkPackageOption pkgs "suwayomi-server" { };

    dataDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/suwayomi-server";
      description = "Data directory for Suwayomi-Server (downloads, config, database)";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "suwayomi";
      description = "User account under which Suwayomi-Server runs";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "suwayomi";
      description = "Group under which Suwayomi-Server runs";
    };

    extraReadWritePaths = lib.mkOption {
      type = lib.types.listOf lib.types.path;
      default = [ ];
      example = [ "/mnt/media/suwayomi" ];
      description = "Additional directories the service is allowed to write to (e.g. external media mounts)";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Open the firewall for the Suwayomi port";
    };

    settings = lib.mkOption {
      type = lib.types.submodule {
        freeformType = format.type;
        options = {
          server = {
            ip = lib.mkOption {
              type = lib.types.str;
              default = "127.0.0.1";
              description = "IP address Suwayomi binds to";
            };

            port = lib.mkOption {
              type = lib.types.port;
              default = 4567;
              description = "Port Suwayomi listens on";
            };

            authMode = lib.mkOption {
              type = lib.types.enum [ "none" "basic_auth" "simple_login" "ui_login" ];
              default = "none";
              example = "basic_auth";
              description = ''
                Authentication mode for Suwayomi-Server.
                - none: no authentication
                - basic_auth: HTTP Basic Auth (requires header on every request)
                - simple_login: login form + cookie session (auto-sent for images)
                - ui_login: JWT-based auth with UI integration
              '';
            };

            authUsername = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = flake.config.me.username;
              description = "Auth username (defaults to the primary user)";
            };

            authPasswordFile = lib.mkOption {
              type = lib.types.nullOr lib.types.path;
              default = null;
              description = "File containing the auth password (use config.age.secrets.\"<name>\".path)";
            };

            downloadAsCbz = lib.mkOption {
              type = lib.types.bool;
              default = false;
              description = "Download chapters as .cbz files";
            };

            systemTrayEnabled = lib.mkOption {
              type = lib.types.bool;
              default = false;
              description = "Enable system tray icon (requires X11)";
            };

            extensionRepos = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
              example = [ "https://raw.githubusercontent.com/.../index.min.json" ];
              description = "URLs of extension repositories";
            };
          };
        };
      };
      default = { };
      description = ''
        Suwayomi-Server HOCON configuration.
        See https://github.com/Suwayomi/Suwayomi-Server/wiki/Configuring-Suwayomi-Server
      '';
    };
  };
}
