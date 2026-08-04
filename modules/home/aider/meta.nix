# Metadata for the aider module (F9b split). Mirrors sibling home modules
# (e.g. modules/home/opencode/meta.nix). No tests.nix exists for aider, so
# tested = false is preserved honestly — no invented coverage.
{
  name = "aider";
  description = "Aider AI pair programming assistant with Ollama model integration, YAML config generation, and CUDA-free package override.";
  category = "programs";
  tags = [ "aider" "ai" "llm" "coding" "ollama" "cli" ];
  provides = [ "my.programs.aider" "my.programs.aider.ollamaModels" "my.programs.aider.settings" ];
  expects = [ ];
  complexity = "simple";
  tested = false;
  homepage = "https://aider.chat";
  maintainer = "seanc";
}
