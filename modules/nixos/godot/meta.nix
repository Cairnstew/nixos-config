{
  name = "godot";
  description = "Godot game engine — multi-version, export templates, GDScript tools, and companion applications";
  category = "gaming";
  tags = [ "gaming" "game-development" "godot" "gdscript" "2d" "3d" "engine" ];
  # T7: the former second provides entry is not declared anywhere (options.nix
  # only declares my.programs.godot) — drop the stale entry.
  provides = [ "my.programs.godot" ];
  complexity = "medium";
  tested = true;
  homepage = "https://godotengine.org";
}
