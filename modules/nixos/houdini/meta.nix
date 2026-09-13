{
  name = "houdini";
  description = "SideFX Houdini — 3D animation, VFX, and procedural generation software with support for local sesinetd license server, automatic Apprentice (NC) license renewal, and an opencode MCP (fxhoudinimcp) + Houdini knowledge skills";
  category = "graphics";
  tags = [ "houdini" "3d" "animation" "vfx" "graphics" "sidefx" "licensing" "mcp" "opencode" ];
  provides = [ "my.programs.houdini" ];
  expects = [ "my.programs.opencode" ];
  complexity = "complex";
  tested = true;
  homepage = "https://www.sidefx.com";
  maintainer = "seanc";
}
