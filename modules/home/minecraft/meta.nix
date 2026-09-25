{
  name = "minecraft";
  description = "Minecraft client launcher (Prism Launcher or Modrinth App) with optional gamescope wrapper";
  category = "gaming";
  tags = [ "gaming" "minecraft" "prismlauncher" "modrinth" "gamescope" ];
  provides = [ "my.programs.minecraft" ];
  expects = [ ];
  complexity = "medium";
  tested = true;
  homepage = "https://prismlauncher.org";
  maintainer = "seanc";

  # External upstream this module consumes — see modules/AGENT.md §4 (upstream schema).
  # prismlauncher-data is an external DATA repo (git-synced via options.nix), not a
  # flake input: data changes belong in that repo, not here. No space registered.
  upstream = {
    repo = "github:Cairnstew/prismlauncher-data";
    mode = "input";
  };
}
