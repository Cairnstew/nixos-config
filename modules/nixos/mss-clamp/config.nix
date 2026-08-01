{ config, lib, pkgs, ... }:
let
  cfg = config.my.services.mssClamp;
  inherit (lib) mkIf;

  mss =
    if cfg.mss != null then
      cfg.mss
    else if config.my.services.tailscale.mtu != null then
      config.my.services.tailscale.mtu - 60
    else
      1140;

  mssValue = toString mss;

  clampScript = pkgs.writeShellScript "mss-clamp" ''
    set -eu
    for iface in ${lib.concatStringsSep " " cfg.interfaces}; do
      for chain in OUTPUT INPUT; do
        ${pkgs.iptables}/bin/iptables -t mangle -D $chain -i "$iface" -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --set-mss ${mssValue} 2>/dev/null || true
        ${pkgs.iptables}/bin/iptables -t mangle -D $chain -o "$iface" -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --set-mss ${mssValue} 2>/dev/null || true
        ${pkgs.iptables}/bin/iptables -t mangle -A $chain -i "$iface" -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --set-mss ${mssValue} 2>/dev/null || true
        ${pkgs.iptables}/bin/iptables -t mangle -A $chain -o "$iface" -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --set-mss ${mssValue} 2>/dev/null || true
      done
    done
  '';
in
{
  config = mkIf cfg.enable {
    # iptables mangle rules survive tailscaled restarts and TUN recreation
    # (interface matches are resolved at packet time, not load time), so the
    # unit only needs to (re)apply when the firewall reloads or something
    # flushes mangle. A timer covers the latter as cheap insurance.
    systemd.services.mss-clamp = {
      description = "Clamp TCP MSS on mesh tunnel interfaces";
      after = [ "tailscaled.service" "firewall.service" ];
      wants = [ "firewall.service" ];
      wantedBy = [ "multi-user.target" ];
      partOf = [ "tailscaled.service" "firewall.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = toString clampScript;
    };

    systemd.timers.mss-clamp = {
      description = "Re-assert TCP MSS clamp rules";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = cfg.reassertInterval;
        OnUnitActiveSec = cfg.reassertInterval;
        Persistent = true;
      };
    };
  };
}
