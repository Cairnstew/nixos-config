{ flake, ... }: {
  virtualisation.docker.enable = true;

  users.users.${flake.config.me.username} = {
    extraGroups = [ "docker" ];
  };

  virtualisation.docker.enableOnBoot = true;
}
