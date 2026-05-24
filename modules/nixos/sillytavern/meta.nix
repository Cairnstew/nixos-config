{
  name = "sillytavern";
  description = "SillyTavern LLM frontend with Ollama integration, declarative presets, and basic auth";
  category = "services";
  tags = [ "sillytavern" "llm" "ai" "chat" "ollama" ];
  provides = [ "my.services.sillytavern" ];
  expects = [ "my.services.ollama" ];
  complexity = "medium";
  tested = true;
  maintainer = "seanc";
  homepage = "https://sillytavern.app";
}
