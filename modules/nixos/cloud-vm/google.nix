# terranix/google.nix
{ config, lib, ... }:

let
  cfg = config.cloud.google;
in {
  options = {
    cloud.google.hosts = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          machine_type   = lib.mkOption { type = lib.types.str; default = "e2-micro"; };
          region         = lib.mkOption { type = lib.types.str; };
          zone           = lib.mkOption { type = lib.types.str; };
          nixos_release  = lib.mkOption { type = lib.types.str; default = "25.11"; };
          project        = lib.mkOption { type = lib.types.str; };
          ssh_public_key = lib.mkOption { type = lib.types.str; default = ""; };
        };
      });
      default     = {};
      description = "GCP hosts to provision";
    };

    # Declare data as valid top-level so mkIf doesn't choke when hosts = {}
    data = lib.mkOption {
      type    = lib.types.attrsOf lib.types.anything;
      default = {};
    };
  };

  config = lib.mkIf (cfg.hosts != {}) {

    terraform.required_providers.google = {
      source  = "hashicorp/google";
      version = "~> 5.0";
    };

    # ── VPC network ───────────────────────────────────────────────────────────
    resource.google_compute_network = lib.mapAttrs (name: _: {
      name                    = "${name}-vpc";
      auto_create_subnetworks = false;
    }) cfg.hosts;

    resource.google_compute_subnetwork = lib.mapAttrs (name: host: {
      name          = "${name}-subnet";
      ip_cidr_range = "10.0.1.0/24";
      region        = host.region;
      network       = "\${google_compute_network.${name}.id}";
    }) cfg.hosts;

    # ── Firewall ──────────────────────────────────────────────────────────────
    resource.google_compute_firewall = lib.mapAttrs (name: _: {
      name    = "${name}-fw";
      network = "\${google_compute_network.${name}.name}";
      allow   = [{ protocol = "tcp"; ports = [ "22" "80" "443" ]; }];
      source_ranges = [ "0.0.0.0/0" ];
    }) cfg.hosts;

    # ── NixOS image lookup ────────────────────────────────────────────────────
    data.google_compute_image = lib.mapAttrs (name: host: {
      family  = "nixos-${lib.replaceStrings ["."] ["-"] host.nixos_release}";
      project = "nixos-cloud";
    }) cfg.hosts;

    # ── Compute instance ──────────────────────────────────────────────────────
    resource.google_compute_instance = lib.mapAttrs (name: host: {
      name         = name;
      machine_type = host.machine_type;
      zone         = host.zone;
      boot_disk    = [{
        initialize_params = [{
          image = "\${data.google_compute_image.${name}.self_link}";
          size  = 20;
          type  = "pd-ssd";
        }];
      }];
      network_interface = [{
        subnetwork    = "\${google_compute_subnetwork.${name}.id}";
        access_config = [{}];
      }];
      metadata.ssh-keys = "root:${host.ssh_public_key}";
    }) cfg.hosts;

    # ── Static IP ─────────────────────────────────────────────────────────────
    resource.google_compute_address = lib.mapAttrs (name: host: {
      name   = "${name}-ip";
      region = host.region;
    }) cfg.hosts;

    # ── Outputs ───────────────────────────────────────────────────────────────
    output = lib.mapAttrs (name: _: {
      value = "\${google_compute_address.${name}.address}";
    }) cfg.hosts;
  };
}