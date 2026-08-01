# cloud/gcp/default.nix — Google Cloud infrastructure (terranix module)
#
# This is a *terranix* module (not a NixOS module). It is evaluated by the
# terranix flakeModule (see modules/flake-parts/cloud.nix) into a
# `config.tf.json`, then driven by OpenTofu:
#
#   nix run .#gcp -- plan
#   nix run .#gcp -- apply
#   nix run .#gcp -- destroy
#
# The provisioning follows the two-stage pattern:
#   1. This file provisions network, IAM, storage and a GPU MIG.
#   2. A pre-baked NixOS GCE image boots on the instances; the full NixOS
#      configuration is then pushed with `nixos-anywhere` / `colmena`
#      (see cloud/README.md). No curl-scripts, no secrets in metadata.
{ lib, ... }:
{
  terraform.required_providers.google = {
    source = "hashicorp/google";
    version = "~> 6.0";
  };

  # ── Variables (supplied via TF_VAR_* by the wrapper) ──────────────────────
  variable.gcp_credentials_file = {
    description = "Path to GCP service account JSON key file";
    type = "string";
  };

  variable.tailscale_auth_key = {
    description = "Tailscale reusable+ephemeral auth key from admin panel";
    type = "string";
    sensitive = true;
  };

  variable.ssh_pub_key = {
    description = "SSH public key to install on GPU instances (for stage-2 deploy)";
    type = "string";
    sensitive = false;
  };

  variable.project = {
    description = "GCP project id (or left empty to read from the SA JSON)";
    type = "string";
    default = "";
  };

  variable.region = {
    description = "GCP region";
    type = "string";
    default = "europe-west4";
  };

  variable.gpu_type = {
    description = "GPU accelerator type";
    type = "string";
    default = "nvidia-l4";
  };

  variable.machine_type = {
    description = "GCP machine type";
    type = "string";
    default = "g2-standard-4";
  };

  variable.image_family = {
    description = "NixOS GCE image family (see cloud/README.md for available releases)";
    type = "string";
    default = "nixos-25.05";
  };

  # ── Project resolution ────────────────────────────────────────────────────
  # Pass the project id explicitly (TF_VAR_project). It can be read from the
  # service account JSON with:  jq -r .project_id <credentials-file>
  provider.google = {
    region = lib.tf.ref "var.region";
    project = lib.tf.ref "var.project";
    credentials = lib.tf.file "\${var.gcp_credentials_file}";
  };

  # ── APIs ──────────────────────────────────────────────────────────────────
  resource.google_project_service.apis = {
    for_each = {
      compute = "compute.googleapis.com";
      iam = "iam.googleapis.com";
      resourcemanager = "cloudresourcemanager.googleapis.com";
      storage = "storage.googleapis.com";
    };
    project = lib.tf.ref "var.project";
    service = lib.tf.ref "each.value";
    disable_on_destroy = false;
  };

  # ── VPC ───────────────────────────────────────────────────────────────────
  resource.google_compute_network.main = {
    name = "main";
    auto_create_subnetworks = false;
    project = lib.tf.ref "var.project";
    depends_on = [ "google_project_service.apis" ];
  };

  resource.google_compute_subnetwork.main = {
    name = "main";
    ip_cidr_range = "10.0.0.0/24";
    region = lib.tf.ref "var.region";
    network = lib.tf.ref "google_compute_network.main.id";
    project = lib.tf.ref "var.project";
  };

  # ── Cloud Router + NAT ────────────────────────────────────────────────────
  resource.google_compute_router.main = {
    name = "main";
    region = lib.tf.ref "var.region";
    network = lib.tf.ref "google_compute_network.main.id";
    project = lib.tf.ref "var.project";
  };

  resource.google_compute_router_nat.main = {
    name = "main";
    router = lib.tf.ref "google_compute_router.main.name";
    region = lib.tf.ref "var.region";
    project = lib.tf.ref "var.project";
    nat_ip_allocate_option = "AUTO_ONLY";
    source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES";
  };

  # ── Firewall ──────────────────────────────────────────────────────────────
  resource.google_compute_firewall.tailscale = {
    name = "allow-tailscale";
    network = lib.tf.ref "google_compute_network.main.name";
    project = lib.tf.ref "var.project";
    allow = [{ protocol = "udp"; ports = [ "41641" ]; }];
    source_ranges = [ "0.0.0.0/0" ];
    target_tags = [ "gpu" ];
  };

  resource.google_compute_firewall.internal = {
    name = "allow-internal";
    network = lib.tf.ref "google_compute_network.main.name";
    project = lib.tf.ref "var.project";
    allow = [{ protocol = "tcp"; ports = [ "0-65535" ]; }
      { protocol = "udp"; ports = [ "0-65535" ]; }
      { protocol = "icmp"; }];
    source_ranges = [ "10.0.0.0/24" ];
  };

  # Allow SSH from anywhere so stage-2 deploys (nixos-anywhere/colmena) work
  # before the instance joins the tailnet.
  resource.google_compute_firewall.ssh = {
    name = "allow-ssh-bootstrap";
    network = lib.tf.ref "google_compute_network.main.name";
    project = lib.tf.ref "var.project";
    allow = [{ protocol = "tcp"; ports = [ "22" ]; }];
    source_ranges = [ "0.0.0.0/0" ];
    target_tags = [ "gpu" ];
  };

  # ── GCS model cache bucket ────────────────────────────────────────────────
  locals.bucket_name = "\${var.project}-model-cache";

  resource.google_storage_bucket.model_cache = {
    name = lib.tf.ref "local.bucket_name";
    location = lib.tf.ref "var.region";
    project = lib.tf.ref "var.project";
    force_destroy = false;
    uniform_bucket_level_access = true;
  };

  # ── Service account for GPU VM ────────────────────────────────────────────
  resource.google_service_account.gpu = {
    account_id = "gpu-vm";
    display_name = "GPU VM Service Account";
    project = lib.tf.ref "var.project";
  };

  resource.google_storage_bucket_iam_member.gpu_cache = {
    bucket = lib.tf.ref "google_storage_bucket.model_cache.name";
    role = "roles/storage.objectAdmin";
    member = "serviceAccount:${lib.tf.ref "google_service_account.gpu.email"}";
  };

  # ── NixOS GCE image ───────────────────────────────────────────────────────
  data.google_compute_image.nixos = {
    family = lib.tf.ref "var.image_family";
    project = "nixos-cloud-images";
  };

  # ── Instance Template (boots NixOS; full config arrives via stage-2) ──────
  resource.google_compute_instance_template.gpu = {
    name_prefix = "gpu-spot-";
    machine_type = lib.tf.ref "var.machine_type";
    project = lib.tf.ref "var.project";
    tags = [ "gpu" ];

    can_ip_forward = true;

    scheduling = {
      preemptible = true;
      automatic_restart = false;
      on_host_maintenance = "TERMINATE";
      provisioning_model = "SPOT";
      instance_termination_action = "STOP";
    };

    guest_accelerator = [{
      type = lib.tf.ref "var.gpu_type";
      count = 1;
    }];

    disk = [{
      source_image = lib.tf.ref "data.google_compute_image.nixos.self_link";
      auto_delete = true;
      boot = true;
      disk_size_gb = 200;
      disk_type = "pd-ssd";
    }];

    network_interface = [{
      subnetwork = lib.tf.ref "google_compute_subnetwork.main.id";
    }];

    service_account = [{
      email = lib.tf.ref "google_service_account.gpu.email";
      scopes = [ "cloud-platform" ];
    }];

    # First-boot SSH key only — no secrets. Tailscale join and the full NixOS
    # configuration are handled by stage-2 deployment, not startup scripts.
    metadata = {
      ssh-keys = "seanc:${lib.tf.ref "var.ssh_pub_key"}";
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
    name = "gpu-spot";
    project = lib.tf.ref "var.project";
    region = lib.tf.ref "var.region";

    base_instance_name = "gpu";
    target_size = 1;

    version = [{
      instance_template = lib.tf.ref "google_compute_instance_template.gpu.id";
    }];

    distribution_policy_zones = [
      "${lib.tf.ref "var.region"}-a"
      "${lib.tf.ref "var.region"}-b"
      "${lib.tf.ref "var.region"}-c"
    ];

    instance_lifecycle_policy = {
      default_action_on_failure = "DO_NOTHING";
    };

    update_policy = {
      type = "PROACTIVE";
      minimal_action = "REPLACE";
      max_surge_fixed = 0;
      max_unavailable_fixed = 3;
    };

    depends_on = [ "google_compute_router_nat.main" ];
  };

  # ── Outputs (consumed by stage-2 colmena/deploy-rs inventory) ─────────────
  output.tailscale_hostname = {
    value = "gpu-spot";
    description = "Tailscale hostname — appears in tailscale status when running";
  };

  output.model_cache_bucket = {
    value = lib.tf.ref "google_storage_bucket.model_cache.name";
    description = "GCS bucket for model cache";
  };

  output.mig_status_cmd = {
    value = "gcloud compute instance-groups managed list-instances gpu-spot --region=${lib.tf.ref "var.region"} --project=${lib.tf.ref "var.project"}";
    description = "Check MIG instance status";
  };
}
