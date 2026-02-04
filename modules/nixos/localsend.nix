{pkgs, config, flake, ...}:
{
  programs.localsend = {
        enable = true;
        openFirewall = true;
  };
}
