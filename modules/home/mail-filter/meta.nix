{
  name = "mail-filter";
  description = "Sieve-based IMAP mail filtering: mbsync pull + pigeonhole sieve-filter driven by the mail taxonomy";
  category = "mail";
  tags = [ "mail" "sieve" "mbsync" "imap" "gmail" "filtering" ];
  provides = [ "my.services.mailFilter" ];
  expects = [ "flake.config.mail" "flake.config.me" ];
  complexity = "complex";
  tested = true;
  maintainer = "seanc";
}