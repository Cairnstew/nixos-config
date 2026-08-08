{
  name = "backup-target";
  description = "Server-side restic backup target: SFTP-chrooted per-source repositories on a data volume, disk-space guard, and restic Prometheus exporter";
  category = "services";
  tags = [ "backup" "restic" "sftp" "storage" ];
  provides = [ "my.services.backup-target" ];
  expects = [ "my.services.ssh" "my.secrets" ];
  complexity = "medium";
  tested = false;
  maintainer = "seanc";
}
