{ flake, pkgs, lib, ... }:
let
  inherit (flake) config inputs;
  inherit (inputs) self;
in
{

  programs.ghostty = {
    enable = true;
    systemd.enable = true;
    package = inputs.ghostty.packages.${pkgs.system}.default;
    
    settings = {
      gtk-titlebar = true; # better on tiling wm
      font-size = 13;
      window-width = 100;
      window-height = 30;
      theme = "catppuccin-mocha";
      keybind = [

        # Split management
        "ctrl+shift+arrow_left=new_split:left"
        "ctrl+shift+arrow_right=new_split:right"
        "ctrl+shift+arrow_down=new_split:down"
        "ctrl+shift+arrow_up=new_split:up"
        "ctrl+arrow_right=goto_split:right"
        "ctrl+arrow_left=goto_split:left"
        "ctrl+arrow_down=goto_split:down"
        "ctrl+arrow_up=goto_split:up"
          
        # Window management
        "ctrl+shift+n=new_window"
        "ctrl+shift+w=close_window"

        # Tab management
        "ctrl+n=new_tab"
        "ctrl+w=close_surface"

        # Copy/Paste
        "ctrl+c=copy_to_clipboard"
        "ctrl+v=paste_from_clipboard"
        "ctrl+a=select_all"
        
      ];
      
    };
    clearDefaultKeybinds= true;
    themes.catppuccin-mocha = {
      background = "1e1e2e";
      cursor-color = "f5e0dc";
      foreground = "cdd6f4";
      palette = [
        "0=#45475a"
        "1=#f38ba8"
        "2=#a6e3a1"
        "3=#f9e2af"
        "4=#89b4fa"
        "5=#f5c2e7"
        "6=#94e2d5"
        "7=#bac2de"
        "8=#585b70"
        "9=#f38ba8"
        "10=#a6e3a1"
        "11=#f9e2af"
        "12=#89b4fa"
        "13=#f5c2e7"
        "14=#94e2d5"
        "15=#a6adc8"
      ];
      selection-background = "353749";
      selection-foreground = "cdd6f4";
    };
    
  };

}


