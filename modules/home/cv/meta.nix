{
  name = "cv";
  description = "CV content MCP server — thin CRUD over the Cairnstew/CV sqlite store.";
  category = "content";
  tags = [ "cv" "portfolio" "mcp" "opencode" ];
  provides = [ "my.programs.cv" ];
  expects = [ "my.programs.opencode" "flake.inputs.cv" ];
  complexity = "low";
  tested = false;

  # External upstream this module wraps — see modules/AGENT.md §4 (upstream schema).
  # Server + schema live in the separate Cairnstew/Cairnstew.github.io repo
  # (flake input `cv`); this module is a thin consumer. No ensemble space
  # registered — work in the upstream repo directly.
  upstream = {
    repo = "github:Cairnstew/Cairnstew.github.io";
    mode = "wrapped";
    flakeInput = "cv";
  };
}
