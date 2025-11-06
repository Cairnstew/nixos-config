{ flake, ... }: {
  services.zerotierone = {
    enable = false;
    joinNetworks = [
      flake.config.me.zerotier_network
    ];
  };
}
