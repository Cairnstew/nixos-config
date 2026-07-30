{ config, lib, ... }:
let
  cfg = config.my.services.suwayomi;
in
{
  assertions = [
    {
      assertion = !cfg.enable || cfg.settings.server.port > 0;
      message = "my.services.suwayomi.settings.server.port must be a valid port number.";
    }
    {
      assertion = !cfg.enable || cfg.user != "";
      message = "my.services.suwayomi.user must not be empty.";
    }
    {
      assertion = !cfg.enable || cfg.group != "";
      message = "my.services.suwayomi.group must not be empty.";
    }
    {
      assertion = !cfg.enable || cfg.settings.server.authMode == "none"
        || (cfg.settings.server.authUsername != null && cfg.settings.server.authPasswordFile != null);
      message = "my.services.suwayomi.settings.server: authUsername and authPasswordFile must be set when authMode is not 'none'.";
    }
    # autoBindTailscaleIp sed pattern must match the template format.
    # The envsubst template uses hierarchical HOCON: "ip" = "127.0.0.1"
    # (NOT the compact server.ip = "..." format the Java app writes later).
    # Checks the generated script contains the sed pattern matching the template.
    # Does NOT test runtime sed execution — requires a VM integration test.
    {
      assertion = !cfg.enable || !cfg.autoBindTailscaleIp
        || lib.hasInfix "autoBindTailscaleIp"
        (config.systemd.services.suwayomi-server.script or "");
      message = ''
        autoBindTailscaleIp sed invocation in services.nix is missing the
        '# autoBindTailscaleIp' comment tag. The sed command may have been
        removed or altered. Check services.nix:63-66.
      '';
    }
    # Retry loop must surround the tailscale ip call to survive the
    # ~5s gap between tailscaled.service reaching "active" and actually
    # obtaining a Tailscale IP at boot.
    {
      assertion = !cfg.enable || !cfg.autoBindTailscaleIp
        || lib.hasInfix "for i in $(seq 1 30)"
        (config.systemd.services.suwayomi-server.script or "");
      message = ''
        autoBindTailscaleIp retry loop is missing. The tailscale ip call must
        be wrapped in a for-loop with a timeout to handle the boot-time race
        where tailscaled reports as started before it has an IP.
        Check services.nix for the "for i in $(seq 1 30)" loop construct.
      '';
    }
  ];
}
