{
  name = "gitreposync";
  description = "Systemd-timer based git repository sync with multiple conflict strategies and agenix token injection.";
  category = "services";
  tags = [ "git" "sync" "systemd" "agenix" ];
  provides = [ "my.services.gitRepoSync" ];
  expects = [ ];
  complexity = "medium";
  tested = true;
}
