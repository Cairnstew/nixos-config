{
  name = "ollama";
  description = "Ollama LLM inference server as an OCI container with model management, MCP integration, and GPU support";
  category = "services";
  tags = [ "ollama" "llm" "ai" "containers" "gpu" "nvidia" "mcp" ];
  provides = [ "my.services.ollama" ];
  expects = [ "my.virtualisation.docker" "my.secrets" ];
  complexity = "complex";
  tested = true;
  maintainer = "seanc";
  homepage = "https://ollama.com";
}
