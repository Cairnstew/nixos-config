{ ... }:

let
  region = "europe-west2";
  zone   = "${region}-a";
in
{
  terraform.required_providers.google = {
    source  = "hashicorp/google";
    version = "~> 5.0";
  };

  variable.gcp_credentials_file = {
    description = "Path to the GCP service account JSON key file";
    type        = "string";
  };

  data.external.sa_json = {
    program = [ "sh" "-c" ''jq -r '{project_id:.project_id}' "$0"'' "\${var.gcp_credentials_file}" ];
  };

  locals.project = "\${data.external.sa_json.result.project_id}";

  provider.google = {
    inherit region zone;
    project     = "\${local.project}";
    credentials = "\${file(var.gcp_credentials_file)}";
  };

  resource.google_compute_instance.test = {
    name         = "test";
    machine_type = "e2-micro";
    inherit zone;

    boot_disk.initialize_params = {
      image = "debian-cloud/debian-12";
    };

    network_interface = [{
      network = "default";
      access_config = [{}];
    }];
  };

  output.instance_ip = {
    value = "\${google_compute_instance.test.network_interface[0].access_config[0].nat_ip}";
  };
}