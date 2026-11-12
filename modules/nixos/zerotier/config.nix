{ config, lib, pkgs, ... }:
let
  inherit (lib) mkIf mkForce;
  cfg = config.my.services.zerotier;

  # ZeroTier claims 2800 bytes no matter what the underlying path carries, so a
  # single large datagram is fragmented past the real path (~1300 B measured on
  # a relayed WAN peer) and silently dropped, while 7–24 byte RakNet/control
  # packets still flow. The connection therefore looks healthy in both logs
  # while the client waits forever for a payload it will never receive. This
  # clamps the interface so the kernel fragments at a size the path delivers.
  clampMtu = pkgs.writeShellScript "zerotier-clamp-mtu" ''
    set -eu
    mtu=${toString cfg.mtu}

    # zt* interfaces only appear after zerotierone has joined (and been
    # authorised on) a network, which lags the service start by seconds.
    i=0
    while [ "$i" -lt 150 ]; do
      i=$((i + 1))
      found=0
      for link in /sys/class/net/zt*; do
        [ -e "$link/mtu" ] || continue
        found=1
        iface=''${link##*/}
        current=$(cat "$link/mtu")
        if [ "$current" -ne "$mtu" ]; then
          ${pkgs.iproute2}/bin/ip link set dev "$iface" mtu "$mtu"
          echo "clamped $iface: mtu $current -> $mtu"
        else
          echo "$iface: already at mtu $mtu"
        fi
      done
      if [ "$found" -eq 1 ]; then
        exit 0
      fi
      sleep 2
    done

    echo "no zt* interface appeared within 300s; nothing to clamp" >&2
    exit 1
  '';
in
{
  config = mkIf cfg.enable {
    services.zerotierone = {
      enable = true;
      joinNetworks = cfg.networks;
      localConf = if cfg.localConf != null then cfg.localConf else { };
      package = if cfg.package != null then cfg.package else pkgs.zerotierone;
    };

    networking.firewall.allowedUDPPorts = mkIf cfg.openFirewall [ 9993 ];

    # Always-on recovery mesh — fully independent of Tailscale.
    # Starts at boot on multi-user.target. UDP 9993 exposed by default (openFirewall).
    systemd.services.zerotierone = {
      wantedBy = [ "multi-user.target" ];
      after = [ "network-pre.target" ];
      wants = [ "network-pre.target" ];
      serviceConfig = {
        Restart = mkForce "on-failure";
        RestartSec = "5";
      };
    };

    # Clamp the MTU of every ZeroTier interface (opt-in via `mtu`). The zt*
    # devices are recreated at the default 2800 MTU on every zerotierone
    # restart, so the unit is both pulled in by zerotierone.service and torn
    # down with it — a plain `wantedBy = multi-user.target` would leave the
    # clamp stale after `systemctl restart zerotierone`.
    systemd.services.zerotier-mtu = mkIf (cfg.mtu != null) {
      description = "Clamp ZeroTier interface MTU to ${toString cfg.mtu}";
      wantedBy = [
        "multi-user.target"
        "zerotierone.service"
      ];
      after = [ "zerotierone.service" ];
      wants = [ "zerotierone.service" ];
      partOf = [ "zerotierone.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = toString clampMtu;
    };
  };
}
