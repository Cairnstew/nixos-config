{ lib, pkgs, config, ... }:
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

            basicAuthEnabled = lib.mkEnableOption "basic access authentication for Suwayomi-Server";

            basicAuthUsername = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "Basic auth username";
            };

            basicAuthPasswordFile = lib.mkOption {
              type = lib.types.nullOr lib.types.path;
              default = null;
              description = "File containing the basic auth password (use config.age.secrets.\"<name>\".path)";
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
