{ flake, ... }: {
  services.zerotierone = {
    enable = true;
    joinNetworks = [
      "363c67c55ab5da47"
      "1c33c1ced07e2ece"
      "60ee7c034a3c75c9"
    ];
  };
}
