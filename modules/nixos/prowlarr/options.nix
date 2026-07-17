{ lib, pkgs, ... }:
let
  indexerField = lib.types.submodule {
    options = {
      name = lib.mkOption {
        type = lib.types.str;
        description = "Field name (e.g. username, password, baseUrl)";
      };
      value = lib.mkOption {
        type = lib.types.raw;
        default = null;
        description = "Field value (omit when using credentialFile)";
      };
      credentialFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = "Agenix secret path for this field (e.g. config.age.secrets.speedcd-password.path)";
      };
    };
  };
in
{
  options.my.services.prowlarr = {
    enable = lib.mkEnableOption "Prowlarr indexer manager/proxy";

    package = lib.mkPackageOption pkgs "prowlarr" { };

    dataDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/prowlarr";
      description = "Data directory for Prowlarr";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Open the firewall for the Prowlarr web interface";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 9696;
      description = "Port for the Prowlarr web interface";
    };

    disableAnalytics = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Disable anonymous usage data collection";
    };

    indexers = lib.mkOption {
      type = lib.types.listOf (lib.types.submodule {
        options = {
          name = lib.mkOption {
            type = lib.types.str;
            description = "Display name for this indexer (e.g. SpeedCD)";
          };
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Whether this indexer is enabled";
          };
          implementation = lib.mkOption {
            type = lib.types.str;
            description = "Prowlarr implementation name (e.g. SpeedCD, TorrentRssIndexer)";
            example = "SpeedCD";
          };
          settings = lib.mkOption {
            type = lib.types.listOf indexerField;
            default = [ ];
            description = "Indexer field configuration";
          };
          priority = lib.mkOption {
            type = lib.types.int;
            default = 25;
            description = "Indexer priority (lower = preferred)";
          };
          appProfileId = lib.mkOption {
            type = lib.types.int;
            default = 1;
            description = "Application profile ID (usually 1 for default)";
          };
        };
      });
      default = [ ];
      description = "Declarative indexer definitions. Credential fields use credentialFile pointing to agenix secrets.";
      example = [
        {
          name = "SpeedCD";
          implementation = "SpeedCD";
          settings = [
            { name = "baseUrl"; value = "https://speed.cd/"; }
            { name = "username"; credentialFile = "config.age.secrets.speedcd-username.path"; }
            { name = "password"; credentialFile = "config.age.secrets.speedcd-password.path"; }
          ];
        }
      ];
    };
  };
}
