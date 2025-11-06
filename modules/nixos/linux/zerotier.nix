{ flake, ... }: {
  services.zerotierone = {
    enable = true;
    joinNetworks = [
      flake.config.me.zerotier_network
    ];
  };
}
