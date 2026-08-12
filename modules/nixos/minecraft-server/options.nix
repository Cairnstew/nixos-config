{ lib, ... }:

let
  inherit (lib) mkEnableOption mkOption types literalExpression;

  # Username → Minecraft UUID (dashed or undashed). Matches nix-minecraft's
  # coercedTo handling.
  uuidMap = types.attrsOf (
    types.coercedTo types.str (v: { uuid = v; }) (types.submodule {
      options.uuid = mkOption {
        type = types.strMatching "([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}|[0-9a-f]{32})";
        description = "Minecraft UUID (dashed or undashed).";
      };
    })
  );
in
{
  options.my.services.minecraftServer = {
    enable = mkEnableOption "declarative Minecraft dedicated servers (nix-minecraft)";

    # EULA: Mojang requires explicit acceptance.
    eula = mkEnableOption "accept Mojang's Minecraft EULA (required to run a server)";

    dataDir = mkOption {
      type = types.path;
      default = "/mnt/data/minecraft";
      description = ''
        Base directory holding each server's world, mods and config.
        Each server lives in <literal>''${dataDir}/&lt;name&gt;</literal>.
        Point this at a large, fast disk (the server host uses /mnt/data).
      '';
    };

    # Default for all servers; per-server can override.
    openFirewall = mkEnableOption "open server ports in the firewall (default for all servers)";

    servers = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          enable = mkOption {
            type = types.bool;
            default = true;
            description = "Whether to run and manage this server.";
          };

          package = mkOption {
            type = types.package;
            description = ''
              Minecraft server package, e.g.
              <literal>pkgs.neoforgeServers.neoforge-1_21_1-21_1_238</literal>,
              <literal>pkgs.paperServers.paper-1_21_1</literal> or
              <literal>pkgs.vanillaServers.vanilla-1_21_1</literal>.
              Available from the nix-minecraft overlay.
            '';
            example = literalExpression ''
              pkgs.neoforgeServers.neoforge-1_21_1-21_1_238
            '';
          };

          jvmOpts = mkOption {
            type = types.str;
            default = "-Xmx4G -Xms2G";
            description = "JVM options for this server (e.g. '-Xms4G -Xmx8G').";
          };

          serverProperties = mkOption {
            type = types.attrsOf (types.oneOf [ types.bool types.int types.str ]);
            default = { };
            description = ''
              Minecraft server.properties values (declarative). See
              https://minecraft.wiki/w/Server.properties
            '';
            example = literalExpression ''
              {
                server-port = 25565;
                max-players = 12;
                motd = "Dragon Technology";
                white-list = true;
                enable-query = true;
              }
            '';
          };

          whitelist = mkOption {
            type = uuidMap;
            default = { };
            description = "Username → UUID map of whitelisted players.";
            example = literalExpression ''
              { seanc = "01234567-89ab-cdef-0123-456789abcdef"; }
            '';
          };

          operators = mkOption {
            type = uuidMap;
            default = { };
            description = "Username → UUID map of operators (level 4 default).";
            example = literalExpression ''
              { seanc = "01234567-89ab-cdef-0123-456789abcdef"; }
            '';
          };

          openFirewall = mkOption {
            type = types.bool;
            default = false;
            description = "Open this server's ports in the firewall. Set module-level openFirewall or per-server.";
          };

          pack = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = ''
              Runtime path of a modpack content directory (from a Prism Launcher
              export or a fetchModrinthModpack derivation). Its
              <literal>mods</literal>, <literal>config</literal>,
              <literal>kubejs</literal>, <literal>scripts</literal>,
              <literal>datapacks</literal> and <literal>defaultconfigs</literal>
              subdirectories are symlinked into the server data dir at service
              start. A plain string is treated as a path on the server's disk
              (not copied into the Nix store) — suitable for large local packs.
              Null = no mods (vanilla).
            '';
            example = "/mnt/data/minecraft/packs/dragon-technology";
          };

          extraSymlinks = mkOption {
            type = types.attrsOf types.path;
            default = { };
            description = ''
              Additional things to symlink into the server data dir, keyed by
              relative path, e.g. <literal>{ "world/datapacks/x" = ./x; }</literal>.
            '';
          };

          restart = mkOption {
            type = types.str;
            default = "on-failure";
            description = "systemd Restart policy for the server unit.";
          };

          managementSystem = mkOption {
            type = types.submodule {
              options = {
                tmux = {
                  enable = mkEnableOption "management via a tmux socket";
                  socketPath = mkOption {
                    type = types.path;
                    default = "/run/minecraft";
                    description = "Directory holding per-server tmux socket files.";
                  };
                };
                systemdSocket = {
                  enable = mkEnableOption "management via systemd socket (journal + FIFO console)";
                  socketPath = mkOption {
                    type = types.path;
                    default = "/run/minecraft";
                    description = "Directory holding per-server FIFO files.";
                  };
                };
              };
            };
            default = { tmux.enable = true; };
            description = "Console management system: tmux (default) or systemd-socket.";
          };
        };
      });
      default = { };
      description = "Per-server Minecraft definitions.";
    };
  };
}
