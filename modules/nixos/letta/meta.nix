{
  name = "letta";
  description = "Letta (formerly MemGPT) — stateful AI agent platform with advanced persistent memory, self-improving agents, and Ollama backend support";
  category = "services";
  tags = [ "letta" "memgpt" "memory" "llm" "ai" "agents" "ollama" "containers" ];
  provides = [ "my.services.letta" ];
  expects = [ "my.services.ollama" ];
  complexity = "complex";
  tested = true;
  maintainer = "seanc";
  homepage = "https://docs.letta.com";
}
