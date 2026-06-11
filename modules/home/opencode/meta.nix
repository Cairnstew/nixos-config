{
  name = "opencode";
  description = "OpenCode AI coding agent with support for 15+ LLM providers, 8 custom skills, 6 custom tools, custom agents, and MCP integration.";
  category = "programs";
  tags = [ "ai" "llm" "coding" "opencode" "skills" "mcp" "nix" "deploy" "secrets" "testing" "docker" "windows" ];
  provides = [
    "my.programs.opencode"
    "my.programs.opencode.skills"
    "my.programs.opencode.agents"
    "my.programs.opencode.mcp"
    "my.programs.opencode.references"
    "my.programs.opencode.plugins"
    "my.programs.opencode.pluginFiles"
    "my.programs.opencode.tools.nix-hosts"
    "my.programs.opencode.tools.nix-eval"
    "my.programs.opencode.tools.nix-flake-check"
    "my.programs.opencode.tools.just"
  ];
  expects = [ ];
  complexity = "medium";
  tested = true;
}
