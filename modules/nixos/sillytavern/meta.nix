{
  name = "sillytavern";
  description = "Thin wrapper wiring the upstream SillyTavern flake module (services.sillytavern-nixos.*) into this config: reverse-proxy upstream, proxy trust, and Ollama model pre-pull";
  category = "services";
  tags = [ "sillytavern" "llm" "ai" "chat" "ollama" "rag" ];
  provides = [ "services.sillytavern-nixos" ];
  expects = [ "my.services.proxy" "my.services.ollama" ];
  complexity = "low";
  tested = true;
  maintainer = "seanc";
  homepage = "https://sillytavern.app";

  # The whole implementation is upstream. `mode = wrapped` because this repo
  # never carried a vendored copy — it consumes the flake input directly and
  # keeps only host-local wiring here. Implementation changes (the module
  # behaviour, the option surface, the seeding machinery, upstream docs) belong
  # in the upstream repo; only the proxy / Ollama wiring stays local.
  #
  # No ensemble space is registered for this upstream, so implementation
  # changes are made in the upstream repo directly and re-pinned with
  #   nix flake update sillytavern
  # See modules/AGENT.md §4.2 and README.md "Upstream".
  upstream = {
    repo = "github:Cairnstew/SillyTavern";
    mode = "wrapped";
    flakeInput = "sillytavern";
  };
}
