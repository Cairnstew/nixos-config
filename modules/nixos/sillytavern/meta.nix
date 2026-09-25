{
  name = "sillytavern";
  description = "SillyTavern LLM frontend with Ollama integration, declarative presets, basic auth, and VectFox RAG memory";
  category = "services";
  tags = [ "sillytavern" "llm" "ai" "chat" "ollama" "vectfox" "rag" "qdrant" ];
  provides = [ "services.sillytavern" ];
  expects = [ "my.services.ollama" "services.qdrant" ];
  complexity = "medium";
  tested = true;
  maintainer = "seanc";
  homepage = "https://sillytavern.app";

  # External upstream this module wraps — see modules/AGENT.md §4 (upstream schema).
  # This module wires config around the upstream Cairnstew/SillyTavern flake
  # module (services.sillytavern.*). No ensemble space is registered — work in
  # the upstream repo directly for implementation changes.
  upstream = {
    repo = "github:Cairnstew/SillyTavern";
    mode = "wrapped";
    flakeInput = "sillytavern";
  };
}
