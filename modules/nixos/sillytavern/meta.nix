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
}
