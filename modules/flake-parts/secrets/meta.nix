{
  name = "secrets";
  description = "Secrets management CLI tools: validate, set, agenix-manager TUI";
  category = "security";
  tags = [ "secrets" "agenix" "age" "encryption" ];
  provides = [
    "devShells.secrets"
    "apps.secrets-validate"
    "apps.secrets-set"
  ];
  complexity = "low";
  tested = false;

  # External upstream this module wraps — see modules/AGENT.md §4 (upstream schema).
  # agenix-manager CLI is the primary tooling here; upstream changes go via the
  # ensemble space, not by editing this repo's tool wrappers.
  upstream = {
    repo = "github:Cairnstew/agenix-manager";
    mode = "wrapped";
    space = "agenix-manager";
    flakeInput = "agenix-manager";
  };
}
