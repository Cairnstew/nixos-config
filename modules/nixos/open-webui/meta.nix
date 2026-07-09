{
  name = "open-webui";
  description = "Open WebUI — self-hosted AI platform with MCP support, persistent memory, RAG, image generation, and Ollama backend integration";
  category = "services";
  tags = [ "open-webui" "llm" "ai" "chat" "ollama" "mcp" "rag" "containers" ];
  provides = [ "my.services.open-webui" ];
  expects = [ "my.services.ollama" ];
  complexity = "complex";
  tested = true;
  maintainer = "seanc";
  homepage = "https://openwebui.com";
}
