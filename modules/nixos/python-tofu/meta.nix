{
  name = "python-tofu";
  description = "Thin wrapper for the upstream python-tofu flake module: enables services.python-tofu, wires the agenix GCP service-account key, and exposes a my.* opt-in for rebuild-time stack reconciliation";
  category = "infrastructure";
  tags = [ "gcp" "opentofu" "terraform" "infrastructure" "cloud" "python" ];
  provides = [ "my.services.python-tofu" ];
  complexity = "simple";
  tested = true;
  maintainer = "seanc";
  homepage = "https://github.com/Cairnstew/python-tofu";

  # The whole implementation — DSL, renderer, CLI, systemd unit and the Nix
  # stack-authoring option tree — lives upstream. This repo consumes the flake
  # input and keeps only host-local wiring (credential path, apply-on-rebuild).
  #
  # Upstream work happens in the upstream checkout, then re-pin the input:
  #   nix flake lock --update-input python-tofu
  # See modules/AGENT.md §4.2 and README.md "Upstream".
  upstream = {
    repo = "github:Cairnstew/python-tofu";
    mode = "wrapped";
    flakeInput = "python-tofu";
  };
}
