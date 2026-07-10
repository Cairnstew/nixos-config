{
  name = "jan";
  description = "Jan — open-source ChatGPT alternative with local LLM inference, MCP support, and Ollama integration";
  category = "services";
  tags = [ "jan" "llm" "ai" "chat" "ollama" "mcp" "desktop" ];
  provides = [ "my.services.jan" ];
  expects = [ "my.services.ollama" ];
  complexity = "simple";
  tested = true;
  maintainer = "seanc";
  homepage = "https://jan.ai";
}
