{
  name = "mail-filter";
  description = "Gmail IMAP label tagging: applies flake.config.mail.tags taxonomy as X-GM-LABELS in place (no moves, no local maildir)";
  category = "mail";
  tags = [ "mail" "imap" "gmail" "labels" "tagging" "x-gm-labels" ];
  provides = [ "my.services.mailFilter" ];
  expects = [ "flake.config.mail" "flake.config.me" ];
  complexity = "complex";
  tested = true;
  maintainer = "seanc";
}
