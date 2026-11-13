{
  # Identity
  name = "thunderbird";
  description = "Mozilla Thunderbird email client with Home Manager integration";
  category = "communication";
  tags = [ "email" "thunderbird" "communication" "gui" ];

  # What this module provides (option paths it owns)
  provides = [
    "my.programs.thunderbird"
    "my.programs.thunderbird.theme"
  ];

  # What this module expects to exist (soft dependencies for agent reasoning)
  expects = [ ];

  # Complexity hint for agents
  complexity = "simple";

  # Test coverage
  theme = {
    kind = "gui";
    mechanism = "css-inject";
    file = "theme.nix";
  };
  tested = true;

  # Optional: link to upstream docs
  homepage = "https://www.thunderbird.net";

  # Optional: who maintains this (GitHub handle or name)
  maintainer = "seanc";

  # Autowiring hints (consumed by future tooling, ignored by Nix today)
  autowire = {
    enable = true;
    priority = 100;
  };
}
