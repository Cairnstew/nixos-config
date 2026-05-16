# terraform/main.nix
{ flake, config, ... }:

let
  region = "europe-west2";
  zone   = "${region}-b";  # b has better L4 spot availability than a
in
{
  terraform.required_providers.google = {
    source  = "hashicorp/google";
    version = "~> 5.0";
  };

  variable.gcp_credentials_file = {
    description = "Path to GCP service account JSON key file";
    type        = "string";
    default     = config.age.secrets.tailscale.cloud-auth.path;
  };

  variable.allowed_ip = {
    description = "Your personal IP (e.g. 1.2.3.4/32) allowed to reach the GPU";
    type        = "string";
  };

  variable.vllm_model = {
    description = "HuggingFace model to serve, e.g. mistralai/Mistral-7B-Instruct-v0.2";
    type        = "string";
    default     = "mistralai/Mistral-7B-Instruct-v0.2";
  };

  variable.hf_token = {
    description = "HuggingFace token (needed for gated models like Llama)";
    type        = "string";
    default     = "";
    sensitive   = true;
  };

  # ── Read project from SA JSON ─────────────────────────────────────────────
  data.external.sa_json = {
    program = [ "sh" "-c" ''jq -r '{project_id:.project_id}' "$0"'' "\${var.gcp_credentials_file}" ];
  };

  locals.project = "\${data.external.sa_json.result.project_id}";

  provider.google = {
    inherit region zone;
    project     = "\${local.project}";
    credentials = "\${file(var.gcp_credentials_file)}";
  };

  # ── Enable APIs ───────────────────────────────────────────────────────────
  resource.google_project_service.apis = {
    for_each = "\${{ for api in toset([\"compute.googleapis.com\", \"iam.googleapis.com\", \"cloudresourcemanager.googleapis.com\"]) : api => api }}";
    project  = "\${local.project}";
    service  = "\${each.value}";
    disable_on_destroy = false;
  };

  # ── VPC ───────────────────────────────────────────────────────────────────
  resource.google_compute_network.main = {
    name                    = "main";
    auto_create_subnetworks = false;
    project                 = "\${local.project}";
    depends_on              = [ "google_project_service.apis" ];
  };

  resource.google_compute_subnetwork.main = {
    name          = "main";
    ip_cidr_range = "10.0.0.0/24";
    inherit region;
    network = "\${google_compute_network.main.id}";
    project = "\${local.project}";
  };

  # ── Firewall ──────────────────────────────────────────────────────────────
  # SSH from your IP only
  resource.google_compute_firewall.ssh = {
    name    = "allow-ssh";
    network = "\${google_compute_network.main.name}";
    project = "\${local.project}";
    allow   = [{ protocol = "tcp"; ports = [ "22" ]; }];
    source_ranges = [ "\${var.allowed_ip}" ];
    target_tags   = [ "gpu" ];
  };

  # vLLM API (OpenAI-compatible) from your IP only
  resource.google_compute_firewall.vllm = {
    name    = "allow-vllm";
    network = "\${google_compute_network.main.name}";
    project = "\${local.project}";
    allow   = [{ protocol = "tcp"; ports = [ "8000" ]; }];
    source_ranges = [ "\${var.allowed_ip}" ];
    target_tags   = [ "gpu" ];
  };

  # Internal traffic within the VPC (for future agent VM)
  resource.google_compute_firewall.internal = {
    name    = "allow-internal";
    network = "\${google_compute_network.main.name}";
    project = "\${local.project}";
    allow   = [{ protocol = "tcp"; ports = [ "0-65535" ]; }
               { protocol = "udp"; ports = [ "0-65535" ]; }
               { protocol = "icmp"; }];
    source_ranges = [ "10.0.0.0/24" ];
  };

  # ── GPU Spot VM ───────────────────────────────────────────────────────────
  resource.google_compute_instance.gpu = {
    name         = "gpu";
    machine_type = "g2-standard-4";  # 4 vCPU, 16GB RAM, 1x L4
    inherit zone;
    project      = "\${local.project}";
    tags         = [ "gpu" ];

    # Spot VM config
    scheduling = {
      preemptible         = true;
      automatic_restart   = false;
      on_host_maintenance = "TERMINATE";
      provisioning_model  = "SPOT";
      instance_termination_action = "STOP";
    };

    # L4 GPU
    guest_accelerator = [{
      type  = "nvidia-l4";
      count = 1;
    }];

    boot_disk.initialize_params = {
      # Deep Learning VM image — comes with CUDA + drivers preinstalled
      image = "projects/ml-images/global/images/family/common-cu121-debian-11-py310";
      size  = 100;  # GB — models can be large
      type  = "pd-ssd";
    };

    network_interface = [{
      subnetwork = "\${google_compute_subnetwork.main.id}";
      access_config = [{}];  # ephemeral public IP
    }];

    # Install and start vLLM on boot
    metadata.startup-script = ''
      #!/bin/bash
      set -e

      # Install vLLM if not already present
      if ! command -v vllm &>/dev/null; then
        pip install vllm huggingface_hub
      fi

      # Start vLLM serving the chosen model
      export HF_TOKEN="\${var.hf_token}"

      nohup vllm serve "\${var.vllm_model}" \
        --host 0.0.0.0 \
        --port 8000 \
        --dtype auto \
        --max-model-len 8192 \
        >> /var/log/vllm.log 2>&1 &
    '';

    metadata_startup_script = null;  # use metadata.startup-script above

    depends_on = [ "google_project_service.apis" ];
  };

  # ── Outputs ───────────────────────────────────────────────────────────────
  output.gpu_ip = {
    value       = "\${google_compute_instance.gpu.network_interface[0].access_config[0].nat_ip}";
    description = "GPU VM public IP — point OpenCode here";
  };

  output.vllm_endpoint = {
    value       = "http://\${google_compute_instance.gpu.network_interface[0].access_config[0].nat_ip}:8000/v1";
    description = "OpenAI-compatible API endpoint for OpenCode / agents";
  };
}