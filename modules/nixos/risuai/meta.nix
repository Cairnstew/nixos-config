{
  name = "risuai";
  description = "RisuAI — LLM roleplay frontend as an OCI container with HypaMemory/SupaMemory, MCP support, and Ollama backend integration";
  category = "services";
  tags = [ "risuai" "roleplay" "llm" "ai" "chat" "ollama" "mcp" "containers" ];
  provides = [ "my.services.risuai" ];
  expects = [ "my.services.ollama" ];
  complexity = "medium";
  tested = true;
  maintainer = "seanc";
  homepage = "https://risuai.net";
}
