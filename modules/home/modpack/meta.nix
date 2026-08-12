{
  name = "modpack";
  description = "Minecraft modpack engineering: Modrinth API lookup via MCP, mods/ directory management, and (planned) jar introspection + patch ledger.";
  category = "gaming";
  tags = [ "minecraft" "modpack" "modrinth" "mcp" "opencode" ];
  provides = [ "my.programs.modpack" ];
  expects = [ "my.programs.opencode" ];
  complexity = "medium";
  tested = true;
  maintainer = "seanc";
}
