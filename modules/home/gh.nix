{ config, ... }:
{
  
  # https://nixos.asia/en/git
  programs = {
    gh = {
      enable = true;
      settings = {
            git_protocol = "https";
            prompt = "enabled";
          };
    };
    
  };

}
