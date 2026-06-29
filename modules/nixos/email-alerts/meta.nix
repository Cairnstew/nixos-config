{
  name = "email-alerts";
  description = "Centralized email alerting via SMTP (Gmail) with msmtp, providing a send-alert script for other services.";
  category = "services";
  tags = [ "email" "alerting" "monitoring" "smtp" "msmtp" ];
  provides = [ "my.services.emailAlerts" ];
  expects = [ "my.secrets" ];
  complexity = "simple";
  tested = true;
  maintainer = "seanc";
}
