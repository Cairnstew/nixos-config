{ config, lib, pkgs, flake, ... }:
let
  cfg = config.my.services.game-servers;
  inherit (flake.inputs) self;

  selfPkgs = self.packages.${pkgs.system} or { };
  a2sExporter = selfPkgs.a2s-exporter or null;

  enabledServers = lib.filterAttrs (_: s: s.enable) cfg.servers;

  stateDirOf = name: server:
    if server.stateDir != null then server.stateDir else "${cfg.dataDir}/${name}";
in
{
  config = lib.mkIf cfg.enable {
    # Wire in-repo package defaults
    my.services.game-servers.monitoring.exporter =
      lib.mkIf (a2sExporter != null) (lib.mkDefault a2sExporter);

    users.users.${cfg.user} = {
      isSystemUser = true;
      inherit (cfg) group;
      home = cfg.dataDir;
      createHome = true;
      description = "Dedicated game server user";
    };

    users.groups.${cfg.group} = { };

    # Ensure each server's install directory exists and is writable
    systemd.tmpfiles.rules = map
      (name:
        let
          stateDir = stateDirOf name enabledServers.${name};
        in
        "d ${stateDir} 0750 ${cfg.user} ${cfg.group} -")
      (builtins.attrNames enabledServers);
    # Firewall: open each enabled server's declared ports
    networking.firewall.allowedTCPPorts = lib.concatMap
      (s:
        lib.optionals s.openFirewall
          (map (p: p.port) (lib.filter (p: p.protocol == "tcp") s.ports)))
      (lib.attrValues enabledServers);

    networking.firewall.allowedUDPPorts = lib.concatMap
      (s:
        lib.optionals s.openFirewall
          (map (p: p.port) (lib.filter (p: p.protocol == "udp") s.ports)))
      (lib.attrValues enabledServers);
  };
}
