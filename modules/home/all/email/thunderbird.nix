{ pkgs, flake, ... }:

let
  # Replace this with your email configured in your flake
  myEmail = flake.config.me.email or "sean.cairnsst@gmail.com";
in
{
  programs.thunderbird = {
    enable = true;

    # Use real Thunderbird package on Linux/macOS, or a placeholder for testing
    package = pkgs.thunderbird;

	profiles.${flake.config.me.username}.isDefault = true;
	
  };

}
