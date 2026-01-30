{ flake, pkgs, lib, ... }:
let
  inherit (flake) config inputs;
  inherit (inputs) self;

in
{
  programs.cudatext = {

    enable = true;
    # https://github.com/Alexey-T/CudaText/blob/master/app/settings_default/default.json
	userSettings = {
	  font_size = 11;                # Slightly larger for better readability on modern displays
	  font_size__linux = 11;         # Same on Linux if applicable
	
	  minimap_show = true;           # Enable minimap (off by default, very modern/Sublime-like)
	
	  numbers_style = 4;             # Relative line numbers (modern Vim-inspired default)
	  numbers_for_carets = true;     # Always show absolute number on caret line(s)
	  numbers_center = false;        # Left-align numbers for a cleaner look
	
	  show_cur_line = true;          # Subtle highlight on current line
	  show_cur_line_only_focused = true; # Limit highlight to active editor only
	
	  ui_theme_auto_mode = true;     # Auto-switch UI theme to match OS light/dark mode
	
	  autocomplete_autoshow_chars = 2; # Auto-show completion list after 2 word chars
	};
	
  	
  };
}
