# modules/nixos/sillytavern/tests.nix
# Local tests for the thin SillyTavern wrapper.
#
# The service itself — its unit, the account seeder, the JSON state seeding and
# its own assertions — is upstream's, and upstream ships its own `checks.*`
# suite (run with `nix flake check` on the input). What is tested HERE is the
# wiring this repo owns: the reverse-proxy upstream.
{ config, ... }:

let
  cfg = config.services.sillytavern-nixos;
  proxyUpstream = config.my.services.proxy.upstreams.sillytavern or null;
in
{
  # ── L0: Nix assertions ─────────────────────────────────────────────────────
  assertions = [
    {
      # The proxy upstream must point at the port the service actually listens
      # on. A mismatch here is silent: Caddy answers 502 and the service looks
      # healthy.
      assertion = !cfg.enable || proxyUpstream == null || proxyUpstream.port == cfg.config.port;
      message = ''
        modules/nixos/sillytavern: the reverse-proxy upstream for SillyTavern
        points at port ${toString (proxyUpstream.port or 0)}, but the service
        listens on ${toString cfg.config.port}. Set
        my.services.proxy.upstreams.sillytavern.port to match, or leave it unset
        so the wrapper derives it.
      '';
    }
  ];
}
