{
  name = "opencode-web";
  description = "opencode web — headless browser UI for opencode, one systemd instance per gitRepoSync-synced repo.";
  category = "services";
  tags = [ "opencode" "ai" "web" "git" ];
  provides = [ "my.services.opencodeWeb" ];
  expects = [ "my.services.gitRepoSync" "my.services.proxy" ];
  complexity = "medium";
  tested = true;
  maintainer = "seanc";
}
