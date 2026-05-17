# terraform/main.nix
{ ... }:
{
  terraform.required_providers.google = {
    source  = "hashicorp/google";
    version = "~> 5.0";
  };

  variable.gcp_credentials_file = {
    description = "Path to GCP service account JSON key file";
    type        = "string";
  };

  variable.tailscale_auth_key = {
    description = "Tailscale reusable+ephemeral auth key from admin panel";
    type        = "string";
    sensitive   = true;
  };

  variable.vllm_model = {
    description = "HuggingFace model to serve";
    type        = "string";
    default     = "mistralai/Mistral-7B-Instruct-v0.2";
  };

  variable.hf_token = {
    description = "HuggingFace token for gated models";
    type        = "string";
    sensitive   = true;
    default     = "";
  };

  variable.region = {
    description = "GCP region";
    type        = "string";
    default     = "europe-west4";
  };

  variable.gpu_type = {
    description = "GPU accelerator type";
    type        = "string";
    default     = "nvidia-l4";
  };

  variable.machine_type = {
    description = "GCP machine type";
    type        = "string";
    default     = "g2-standard-4";
  };

  # ── Project from SA JSON ──────────────────────────────────────────────────
  data.external.sa_json = {
    program = [ "sh" "-c" ''jq -r '{project_id:.project_id}' "$0"'' "\${var.gcp_credentials_file}" ];
  };

  locals.project = "\${data.external.sa_json.result.project_id}";

  provider.google = {
    region      = "\${var.region}";
    project     = "\${local.project}";
    credentials = "\${file(var.gcp_credentials_file)}";
  };

  # ── APIs ──────────────────────────────────────────────────────────────────
  resource.google_project_service.apis = {
    for_each = "\${{ for api in toset([\"compute.googleapis.com\", \"iam.googleapis.com\", \"cloudresourcemanager.googleapis.com\", \"storage.googleapis.com\"]) : api => api }}";
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
    region        = "\${var.region}";
    network       = "\${google_compute_network.main.id}";
    project       = "\${local.project}";
  };

  # ── Cloud Router + NAT ────────────────────────────────────────────────────
  resource.google_compute_router.main = {
    name    = "main";
    region  = "\${var.region}";
    network = "\${google_compute_network.main.id}";
    project = "\${local.project}";
  };

  resource.google_compute_router_nat.main = {
    name                               = "main";
    router                             = "\${google_compute_router.main.name}";
    region                             = "\${var.region}";
    project                            = "\${local.project}";
    nat_ip_allocate_option             = "AUTO_ONLY";
    source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES";
  };

  # ── Firewall ──────────────────────────────────────────────────────────────
  resource.google_compute_firewall.tailscale = {
    name          = "allow-tailscale";
    network       = "\${google_compute_network.main.name}";
    project       = "\${local.project}";
    allow         = [{ protocol = "udp"; ports = [ "41641" ]; }];
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

  # ── GCS model cache bucket ────────────────────────────────────────────────
  resource.google_storage_bucket.model_cache = {
    name                        = "\${local.project}-model-cache";
    location                    = "\${var.region}";
    project                     = "\${local.project}";
    force_destroy               = false;
    uniform_bucket_level_access = true;
  };

  # ── Service account for GPU VM ────────────────────────────────────────────
  resource.google_service_account.gpu = {
    account_id   = "gpu-vm";
    display_name = "GPU VM Service Account";
    project      = "\${local.project}";
  };

  resource.google_storage_bucket_iam_member.gpu_cache = {
    bucket = "\${google_storage_bucket.model_cache.name}";
    role   = "roles/storage.objectAdmin";
    member = "serviceAccount:\${google_service_account.gpu.email}";
  };

  # ── Instance Template ─────────────────────────────────────────────────────
  resource.google_compute_instance_template.gpu = {
    name_prefix  = "gpu-spot-";
    machine_type = "\${var.machine_type}";
    project      = "\${local.project}";
    tags         = [ "gpu" ];

    can_ip_forward = true;

    scheduling = {
      preemptible         = true;
      automatic_restart   = false;
      on_host_maintenance = "TERMINATE";
      provisioning_model  = "SPOT";
      instance_termination_action = "STOP";
    };

    guest_accelerator = [{
      type  = "\${var.gpu_type}";
      count = 1;
    }];

    disk = [{
      source_image = "projects/deeplearning-platform-release/global/images/family/common-cu129-ubuntu-2404-nvidia-580";
      auto_delete  = true;
      boot         = true;
      disk_size_gb = 200;
      disk_type    = "pd-ssd";
    }];

    network_interface = [{
      subnetwork = "\${google_compute_subnetwork.main.id}";
    }];

    service_account = [{
      email  = "\${google_service_account.gpu.email}";
      scopes = [ "cloud-platform" ];
    }];

    metadata = {
      startup-script = ''
        #!/bin/bash
        set -euo pipefail
        exec >> /var/log/startup.log 2>&1

        echo "==> $(date) starting up"

        # ── Install Docker ────────────────────────────────────────────────────
        if ! command -v docker &>/dev/null; then
          echo "==> installing docker"
          curl -fsSL https://get.docker.com | sh
          systemctl enable --now docker
        fi

        # ── Configure nvidia-container-toolkit for Docker ─────────────────────
        if ! nvidia-ctk runtime list 2>/dev/null | grep -q docker; then
          echo "==> configuring nvidia-container-toolkit"
          nvidia-ctk runtime configure --runtime=docker
          systemctl restart docker
        fi

        # ── Install Tailscale ─────────────────────────────────────────────
        if ! command -v tailscale &>/dev/null; then
          echo "==> installing tailscale"
          curl -fsSL https://tailscale.com/install.sh | sh
        fi

        # ── Join tailnet ──────────────────────────────────────────────────
        echo "==> joining tailnet"
        tailscale up \
          --authkey="${"\${var.tailscale_auth_key}"}" \
          --hostname="gpu-spot" \
          --accept-dns=false \
          --ssh

        # Wait for Tailscale IP
        echo "==> waiting for tailscale IP"
        TS_IP=""
        for i in $(seq 1 30); do
          TS_IP=$(tailscale ip -4 2>/dev/null || true)
          if [ -n "$TS_IP" ]; then
            echo "==> tailscale IP: $TS_IP"
            break
          fi
          sleep 2
        done

        if [ -z "$TS_IP" ]; then
          echo "==> ERROR: tailscale failed to get IP"
          exit 1
        fi

        # ── Start vLLM via Docker ─────────────────────────────────────────
        if ! docker ps --format '{{.Names}}' | grep -q '^vllm$'; then
          echo "==> starting vllm with model ${"\${var.vllm_model}"}"

          # Pull first so we can see download progress in logs
          docker pull vllm/vllm-openai:latest

          docker run -d \
            --name vllm \
            --restart unless-stopped \
            --gpus all \
            --network host \
            --shm-size 16g \
            -v /mnt/models:/root/.cache/huggingface \
            -e HF_TOKEN="${"\${var.hf_token}"}" \
            vllm/vllm-openai:latest \
            --model "${"\${var.vllm_model}"}" \
            --host "$TS_IP" \
            --port 8000 \
            --dtype auto \
            --max-model-len 8192
        fi

        echo "==> done. vLLM endpoint: http://$TS_IP:8000/v1"
        echo "==> watch logs: docker logs -f vllm"
      '';
    };

    lifecycle = {
      create_before_destroy = true;
    };

    depends_on = [
      "google_project_service.apis"
      "google_compute_router_nat.main"
      "google_service_account.gpu"
    ];
  };

  # ── Regional MIG ──────────────────────────────────────────────────────────
  resource.google_compute_region_instance_group_manager.gpu = {
    name    = "gpu-spot";
    project = "\${local.project}";
    region  = "\${var.region}";

    base_instance_name = "gpu";
    target_size        = 1;

    version = [{
      instance_template = "\${google_compute_instance_template.gpu.id}";
    }];

    distribution_policy_zones = [
      "\${var.region}-a"
      "\${var.region}-b"
      "\${var.region}-c"
    ];

    instance_lifecycle_policy = {
      default_action_on_failure = "DO_NOTHING";
    };

    update_policy = {
      type                  = "PROACTIVE";
      minimal_action        = "REPLACE";
      max_surge_fixed       = 0;
      max_unavailable_fixed = 3;
    };

    depends_on = [ "google_compute_router_nat.main" ];
  };

  # ── Outputs ───────────────────────────────────────────────────────────────
  output.tailscale_hostname = {
    value       = "gpu-spot";
    description = "Tailscale hostname — appears in tailscale status when running";
  };

  output.vllm_endpoint = {
    value       = "http://gpu-spot:8000/v1";
    description = "OpenAI-compatible endpoint (reachable over Tailscale only)";
  };

  output.model_cache_bucket = {
    value       = "\${google_storage_bucket.model_cache.name}";
    description = "GCS bucket for model cache";
  };

  output.mig_status_cmd = {
    value       = "gcloud compute instance-groups managed list-instances gpu-spot --region=\${var.region} --project=\${local.project}";
    description = "Check MIG instance status";
  };

  output.vllm_logs_cmd = {
    value       = "tailscale ssh root@gpu-spot -- docker logs -f vllm";
    description = "Watch vLLM logs remotely";
  };
}