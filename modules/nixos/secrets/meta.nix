{
  name = "secrets";
  description = "Agenix secrets managed via agenix-manager with flat .age files";
  category = "system";
  tags = [ "secrets" "agenix" "agenix-manager" "encryption" "security" ];
  provides = [ ];
  expects = [ ];
  complexity = "low";
  tested = true;
  maintainer = "seanc";

  # External upstream this module wraps — see modules/AGENT.md §4 (upstream schema).
  # Changes to agenix-manager itself belong upstream via the ensemble space, not here.
  upstream = {
    repo = "github:Cairnstew/agenix-manager";
    mode = "wrapped";
    space = "agenix-manager";
    flakeInput = "agenix-manager";
  };
}
