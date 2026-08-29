{
  name = "cv";
  description = "CV content MCP server — thin CRUD over the Cairnstew/CV sqlite store.";
  category = "content";
  tags = [ "cv" "portfolio" "mcp" "opencode" ];
  provides = [ "my.programs.cv" ];
  expects = [ "my.programs.opencode" "flake.inputs.cv" ];
  complexity = "low";
  tested = false;
}