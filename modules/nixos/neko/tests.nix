{ config, lib, ... }:
let
  cfg = config.my.services.neko;
in
{
  assertions = [
    {
      assertion = !cfg.enable || cfg.port > 0;
      message = "my.services.neko.port must be a valid port number.";
    }
    {
      assertion = !cfg.enable || cfg.webrtcPortRange.from < cfg.webrtcPortRange.to;
      message = "my.services.neko.webrtcPortRange.from must be less than webrtcPortRange.to.";
    }
    {
      assertion = !cfg.enable || cfg.webrtcPortRange.from > 0;
      message = "my.services.neko.webrtcPortRange.from must be a valid port number.";
    }
    {
      assertion = !cfg.enable || cfg.webrtcPortRange.to > 0;
      message = "my.services.neko.webrtcPortRange.to must be a valid port number.";
    }
    {
      assertion = !cfg.enable || cfg.shmSize != "";
      message = "my.services.neko.shmSize must not be empty.";
    }
    # NOTE: stripPrefix verification for /neko/ path.
    # Neko's web UI loads from root-relative paths for JS/CSS assets,
    # and its WebSocket signaling uses root-relative WS connections.
    # If the dashboard or WS connection fails after deployment, try
    # setting stripPrefix = false in the host config:
    #   my.services.proxy.upstreams.neko.stripPrefix = false;
  ];
}
