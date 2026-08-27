{
  name = "opencode";
  description = "OpenCode AI coding agent with support for 15+ LLM providers, 10 custom skills, 6 custom tools, 7 custom commands, 7 custom agents, and MCP integration.";
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
    "my.programs.opencode.ensemble"
    "my.programs.opencode.tools.nix-hosts"
    "my.programs.opencode.tools.nix-eval"
    "my.programs.opencode.tools.nix-flake-check"
    "my.programs.opencode.tools.just"
  ];
  expects = [ ];
  complexity = "medium";
  tested = true; # validated live 2026-08-23: wrapper dispatch selected ox-alpha-free under weekly=100%, sync wrote triage modelsByAgent; 2026-08-26: pacing.enable gate fix live-verified against real cache (rolling 1%/weekly 55%/monthly 45% — all four pipeline agents BLOCKED before, resolve opencode-go/mimo-v2.5 after), nixtest regression 5/5, server switched to gen 246
}
