{
  name = "backup-source";
  description = "Client-side restic backup source: scheduled per-job backups pushed over SFTP to a backup-target host, with namespaced defaults and agenix secret wiring";
  category = "services";
  tags = [ "backup" "restic" "sftp" ];
  provides = [ "my.services.backup-source" ];
  expects = [ "my.services.backup-target" "my.secrets" ];
  complexity = "medium";
  tested = false;
  maintainer = "seanc";
}
