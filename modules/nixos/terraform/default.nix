# terraform/main.nix
{ config, ... }:

let
  region = "europe-west2";
  zone   = "${region}-b";
in
{
  terraform.required_providers.google = {
    source  = "hashicorp/google";
    version = "~> 5.0";
  };

  variable.gcp_credentials_file = {
    description = "Path to GCP service account JSON key file";
    type        = "string";
    default     = config.secrets.names.gcloud-auth.file;
  };

  variable.tailscale_auth_key = {
    description = "Tailscale reusable+ephemeral auth key from admin panel";
    type        = "string";
    sensitive   = true;
    default     = config.secrets.names.tailscale-cloud-auth.file;
  };

  variable.vllm_model = {
    description = "HuggingFace model to serve";
    type        = "string";
    default     = "mistralai/Mistral-7B-Instruct-v0.2";
  };

  variable.hf_token = {
    description = "HuggingFace token for gated models";
    type        = "string";
    default     = config.secrets.names.huggingface-token.file;
    sensitive   = true;
  };

  # ── Project from SA JSON ──────────────────────────────────────────────────
  data.external.sa_json = {
    program = [ "sh" "-c" ''jq -r '{project_id:.project_id}' "$0"'' "\${var.gcp_credentials_file}" ];
  };

  locals.project = "\${data.external.sa_json.result.project_id}";

  provider.google = {
    inherit region zone;
    project     = "\${local.project}";
    credentials = "\${file(var.gcp_credentials_file)}";
  };

  # ── APIs ──────────────────────────────────────────────────────────────────
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
  # Tailscale needs outbound UDP 41641 — outbound is open by default on GCP.
  # We only need inbound for the Tailscale coordination + DERP fallback.
  # vLLM port is NOT exposed publicly — only reachable over tailnet.

  resource.google_compute_firewall.tailscale = {
    name    = "allow-tailscale";
    network = "\${google_compute_network.main.name}";
    project = "\${local.project}";
    allow   = [{ protocol = "udp"; ports = [ "41641" ]; }];
    # Tailscale's coordination servers — direct connection works without this
    # but it helps on networks with strict egress filtering
    source_ranges = [ "0.0.0.0/0" ];
    target_tags   = [ "gpu" ];
  };

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
    machine_type = "g2-standard-4";
    inherit zone;
    project      = "\${local.project}";
    tags         = [ "gpu" ];

    scheduling = {
      preemptible         = true;
      automatic_restart   = false;
      on_host_maintenance = "TERMINATE";
      provisioning_model  = "SPOT";
      instance_termination_action = "STOP";
    };

    guest_accelerator = [{
      type  = "nvidia-l4";
      count = 1;
    }];

    boot_disk.initialize_params = {
      image = "projects/ml-images/global/images/family/common-cu121-debian-11-py310";
      size  = 100;
      type  = "pd-ssd";
    };

    network_interface = [{
      subnetwork = "\${google_compute_subnetwork.main.id}";
      # No access_config = no public IP at all
    }];

    metadata.startup-script = ''
      #!/bin/bash
      set -euo pipefail
      exec >> /var/log/startup.log 2>&1

      echo "==> $(date) starting up"

      # ── Install Tailscale ────────────────────────────────────────────────
      if ! command -v tailscale &>/dev/null; then
        echo "==> installing tailscale"
        curl -fsSL https://tailscale.com/install.sh | sh
      fi

      # ── Join tailnet ─────────────────────────────────────────────────────
      echo "==> joining tailnet"
      tailscale up \
        --authkey="${"\${var.tailscale_auth_key}"}" \
        --hostname="gpu-spot" \
        --accept-routes \
        --ssh  # enables Tailscale SSH so you don't need a separate key

      # ── Install vLLM ────────────────────────────────────────────────────
      if ! command -v vllm &>/dev/null; then
        echo "==> installing vllm"
        pip install vllm huggingface_hub
      fi

      # ── Start vLLM ──────────────────────────────────────────────────────
      echo "==> starting vllm with model ${"\${var.vllm_model}"}"
      export HF_TOKEN="${"\${var.hf_token}"}"

      # Listen only on the Tailscale interface (100.x.x.x)
      TS_IP=$(tailscale ip -4)

      nohup vllm serve "${"\${var.vllm_model}"}" \
        --host "$TS_IP" \
        --port 8000 \
        --dtype auto \
        --max-model-len 8192 \
        >> /var/log/vllm.log 2>&1 &

      echo "==> done. vLLM endpoint: http://$TS_IP:8000/v1"
    '';

    depends_on = [ "google_project_service.apis" ];
  };

  # ── Outputs ───────────────────────────────────────────────────────────────
  output.tailscale_hostname = {
    value       = "gpu-spot";
    description = "Tailscale hostname — use this to reach vLLM from your laptop";
  };

  output.vllm_endpoint = {
    value       = "http://gpu-spot:8000/v1";
    description = "OpenAI-compatible endpoint (reachable over Tailscale only)";
  };
}