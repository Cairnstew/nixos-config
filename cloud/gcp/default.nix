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
#   1. This file provisions network, IAM, and storage (infra only).
#   2. A pre-baked NixOS GCE image boots on the instances; the full NixOS
#      configuration is then pushed with `nixos-anywhere` / `colmena`
#      (see cloud/README.md). No curl-scripts, no secrets in metadata.
{ lib, ... }:
{
  imports = [ ./bigquery.nix ];

  terraform.required_providers.google = {
    source = "hashicorp/google";
    version = "~> 6.0";
  };

  # ── Variables (supplied via TF_VAR_* by the wrapper) ──────────────────────
  variable.gcp_credentials_file = {
    description = "Path to GCP service account JSON key file";
    type = "string";
    default = "/run/agenix/gcloud-auth";
  };

  # (tailscale_auth_key + ssh_pub_key variables removed — no instances to use them)

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

  # (gpu_type, machine_type, image_family variables removed — no instances provisioned)

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
      bigquery = "bigquery.googleapis.com";
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

  # ── BigQuery (via bigquery.nix module) ────────────────────────────────────
  # Datasets are defined via bigquery.datasets option.
  # Default "main" dataset — extend via extraBigqueryDatasets or NixOS options.
  bigquery.datasets.main = {
    dataset_id = "main";
    friendly_name = "Main";
    description = "Primary BigQuery dataset (free tier: 10 GB storage, 1 TB queries/month)";
    labels.cost-center = "free-tier";
  };

  # (GPU service account + IAM binding removed — no instances to use them)
  # Re-add alongside the instance template when deploying GPU VMs.

  # (NixOS GCE image data source removed — no instances to use it)

  # ── Outputs ────────────────────────────────────────────────────────────────
  # (GPU instance template + MIG removed — they cost money.
  #  Re-add when ready to deploy.)
  output.network_name = {
    value = lib.tf.ref "google_compute_network.main.name";
    description = "VPC network name";
  };

  output.subnetwork_name = {
    value = lib.tf.ref "google_compute_subnetwork.main.name";
    description = "Subnetwork name";
  };

  output.model_cache_bucket = {
    value = lib.tf.ref "google_storage_bucket.model_cache.name";
    description = "GCS bucket for model cache";
  };

  # BigQuery outputs are generated by bigquery.nix
}
