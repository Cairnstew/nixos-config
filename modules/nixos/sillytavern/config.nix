# modules/nixos/sillytavern/config.nix
# Host-local wiring for the upstream SillyTavern flake module.
#
# There are no `my.*` options here on purpose: the upstream module owns the
# whole option surface under `services.sillytavern-nixos.*`, and re-exporting
# it under `my.*` would mean duplicating every option and drifting out of sync
# on each `nix flake update`. What legitimately stays local is what is about
# THIS config rather than about SillyTavern: how the reverse proxy reaches the
# service, and which models are pulled before the server answers a request.
{ config, lib, pkgs, ... }:

let
  cfg = config.services.sillytavern-nixos;
  inherit (import ../proxy/lib.nix) trustProxyEnv;

  # The account's connection profiles, as SillyTavern keeps them in
  # settings.json (`extension_settings.connectionManager.profiles`). Upstream
  # models settings.json as free-form JSON, so the profiles are READ OUT of it
  # rather than declared a second time.
  connectionProfiles =
    lib.attrByPath [ "extension_settings" "connectionManager" "profiles" ] [ ] cfg.settings.common;

  # Only Ollama profiles name a model that lives on this host. Everything else
  # (OpenAI, Claude, …) is a remote API and has nothing to pull.
  ollamaModels = lib.unique (
    lib.filter (m: m != "")
      (
        lib.map (p: p.model or "")
          (lib.filter (p: (p.api or "") == "ollama") (lib.filter builtins.isAttrs connectionProfiles))
      )
  );

  ollamaPullScript = pkgs.writeShellScript "sillytavern-ollama-pull" ''
    ${lib.concatStringsSep "\n" (
      lib.filter (m: m != "") (
        lib.map (model: ''
          echo "sillytavern: pulling ${model} via ollama..."
          ${pkgs.docker}/bin/docker exec ollama ollama pull ${lib.escapeShellArg model} \
            || echo "sillytavern: WARN: failed to pull ${model}"
        '') ollamaModels
      )
    )}
  '';
in
{
  config = lib.mkIf cfg.enable {
    # SillyTavern is an Express app behind Caddy: it has to trust the
    # X-Forwarded-For header Caddy sets, or every request looks like it came
    # from 127.0.0.1 (which also trips the private-address allowlist).
    services.sillytavern-nixos.environment = trustProxyEnv "express";

    # Pull the Ollama models the account's profiles point at before the server
    # starts, so a fresh activation does not serve a model that was never
    # downloaded. A failed pull is a warning, not a start failure — the model
    # may already be present, or Ollama may be down.
    systemd.services.sillytavern.serviceConfig.ExecStartPre = lib.mkAfter [ "+${ollamaPullScript}" ];

    # Register with reverse proxy
    my.services.proxy.upstreams.sillytavern = {
      port = cfg.config.port;
      path = "/sillytavern/";
      displayName = "SillyTavern";
      trustProxy = "express";
      # Caddy's handle_path strips /sillytavern prefix automatically,
      # so no htmlBase / subs_filter needed. WebSocket is auto-detected.
      # Root-relative SPA paths are proxied via extraLocations below.
      extraLocations = [
        # SPA frontend assets
        ''
          handle /assets/* {
            reverse_proxy 127.0.0.1:${toString cfg.config.port}
          }
        ''
        # Stylesheets
        ''
          handle /css/* {
            reverse_proxy 127.0.0.1:${toString cfg.config.port}
          }
        ''
        # JavaScript scripts
        ''
          handle /scripts/* {
            reverse_proxy 127.0.0.1:${toString cfg.config.port}
          }
        ''
        # REST API
        ''
          handle /api/* {
            reverse_proxy 127.0.0.1:${toString cfg.config.port}
          }
        ''
        # User content (avatars, uploads)
        ''
          handle /user/* {
            reverse_proxy 127.0.0.1:${toString cfg.config.port}
          }
        ''
        # Character card data
        ''
          handle /characters/* {
            reverse_proxy 127.0.0.1:${toString cfg.config.port}
          }
        ''
        # Chat history
        ''
          handle /chats/* {
            reverse_proxy 127.0.0.1:${toString cfg.config.port}
          }
        ''
        # Background images
        ''
          handle /backgrounds/* {
            reverse_proxy 127.0.0.1:${toString cfg.config.port}
          }
        ''
        # Notification sounds
        ''
          handle /sounds/* {
            reverse_proxy 127.0.0.1:${toString cfg.config.port}
          }
        ''
      ];
    };
  };
}
