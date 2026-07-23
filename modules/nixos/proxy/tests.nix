{ config, lib, ... }:
let
  cfg = config.my.services.proxy;
  enabledUpstreams = lib.filterAttrs (_: u: u.enable) cfg.upstreams;
in
{
  assertions = [
    {
      assertion = !cfg.enable || cfg.port > 0;
      message = "my.services.proxy.port must be a valid port number.";
    }
    {
      assertion = !cfg.enable || cfg.listenAddresses != [ ];
      message = "my.services.proxy.listenAddresses must not be empty.";
    }
    {
      assertion = !cfg.enable || cfg.dashboard.title != "";
      message = "my.services.proxy.dashboard.title must not be empty.";
    }
    {
      assertion = !cfg.enable || cfg.tailscaleServe.httpsPort > 0;
      message = "my.services.proxy.tailscaleServe.httpsPort must be a valid port number.";
    }
    # Each upstream path must start with /
    {
      assertion = !cfg.enable
        || lib.all (u: lib.hasPrefix "/" u.path) (builtins.attrValues enabledUpstreams);
      message = "my.services.proxy.upstreams.*.path must start with /.";
    }
    # Upstream host consistency: warn when an upstream uses autoBindTailscaleIp on its service
    # but the proxy host still points at 127.0.0.1 (the upstream won't be reachable).
    # This cannot be checked automatically (Tailscale IP is runtime-known), so this is a
    # meta-check that the user has overridden the host when needed.
  ];

  # Diagnostic warnings — shown at eval time when upstream host mismatch is suspected
  warnings =
    let
      suwayomiCfg = config.my.services.suwayomi or { };
      suwayomiUpstream = cfg.upstreams.suwayomi or { };
    in
    lib.optional (cfg.enable && suwayomiCfg.enable or false && suwayomiCfg.autoBindTailscaleIp or false && suwayomiUpstream.host or "127.0.0.1" == "127.0.0.1")
      "my.services.suwayomi has autoBindTailscaleIp enabled but my.services.proxy.upstreams.suwayomi.host is still 127.0.0.1 — Caddy will not reach suwayomi. Set my.services.proxy.upstreams.suwayomi.host to the Tailscale IP.";
}
