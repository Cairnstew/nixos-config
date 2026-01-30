{ flake, pkgs, lib, ... }:
let
  inherit (flake) config inputs;
  inherit (inputs) self;
in
{
  dconf = {
        settings = {
          # ...
          "org/gnome/shell" = {
            favorite-apps = [
              "firefox.desktop"
              "code.desktop"
              "org.gnome.Terminal.desktop"
              "spotify.desktop"
              "virt-manager.desktop"
            ];
          };
          "org/gnome/desktop/interface" = {
            color-scheme = "prefer-dark";
            enable-hot-corners = false;
            can-change-accels = true;
          };
          "org/gnome/desktop/wm/preferences" = {
            workspace-names = [ "Main" ];
          };
          "org/gnome/desktop/background" = {
            picture-uri = "file:///run/current-system/sw/share/backgrounds/gnome/vnc-l.png";
            picture-uri-dark = "file:///run/current-system/sw/share/backgrounds/gnome/vnc-d.png";
          };
          "org/gnome/desktop/screensaver" = {
            picture-uri = "file:///run/current-system/sw/share/backgrounds/gnome/vnc-d.png";
            primary-color = "#3465a4";
            secondary-color = "#000000";
          };
        };
      };
      gtk = {
        enable = true;
        gtk3 = {
          extraConfig = {
            gtk-application-prefer-dark-theme = true;
          };
        };
        iconTheme = {
          name = "Papirus-Dark";
        };
        theme = {
          name = "Breeze-Dark";
        };
      };
      programs = {
        alacritty = {
          enable = true;
          theme = "gruvbox_material_hard_dark";
        };
      };
      xdg = {
        configFile = {
          "gtk-3.0/settings.ini" = {
            force = true;
          };
          "gtk-4.0/settings.ini" = {
            force = true;
          };
        };
      };
}
