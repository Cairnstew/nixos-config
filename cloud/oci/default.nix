# cloud/oci/default.nix — Oracle Cloud Infrastructure (terranix module)
#
# Terranix module (not a NixOS module) evaluated into `config.tf.json` and
# driven by OpenTofu via the terranix flakeModule:
#
#   nix run .#oci.plan
#   nix run .#oci.apply
#   nix run .#oci.destroy
#
# Basic always-free footprint (home region only — uk-london-1):
#   • 1× Ampere A1.Flex instance (1 OCPU / 6 GB — inside the 2 OCPU / 12 GB pool)
#   • 100 GB block volume (inside the 200 GB pool)
#   • VCN + internet gateway + route + security list
#
# Two-stage pattern (same as cloud/gcp + cloud/aws): this provisions the host
# with only an SSH bootstrap key in metadata (no secrets in metadata); the full
# NixOS configuration — Tailscale join, service deployment — is pushed in stage 2
# with `nixos-anywhere` / `colmena` (see cloud/README.md).
#
# Credentials are read by the `oracle/oci` provider from the agenix `oci-cloud`
# secret via `OCI_CONFIG_FILE` (set by the wrapper in modules/flake-parts/cloud.nix).
{ lib, ... }:
{
  terraform.required_providers.oci = {
    source = "oracle/oci";
    version = "~> 9.0";
  };

  # ── Variables (supplied via TF_VAR_* by the wrapper) ──────────────────────
  variable.tenancy_ocid = {
    description = "OCI tenancy OCID (extracted from the oci-cloud secret) — also the root compartment";
    type = "string";
  };

  variable.ssh_pub_key = {
    description = "SSH public key installed in instance metadata (for stage-2 bootstrap)";
    type = "string";
  };

  variable.compartment_ocid = {
    description = "Compartment to deploy into (defaults to the tenancy/root compartment)";
    type = "string";
    default = "";
  };

  variable.oci_region = {
    description = "OCI region — MUST match the region in the oci-cloud secret (home region for Always Free)";
    type = "string";
    default = "uk-london-1";
  };

  variable.ocpus = {
    description = "A1.Flex OCPUs (Always Free pool: 2 OCPU / 12 GB total)";
    type = "number";
    default = 1;
  };

  variable.memory_gbs = {
    description = "A1.Flex memory in GB (Always Free pool: 2 OCPU / 12 GB total)";
    type = "number";
    default = 6;
  };

  variable.data_volume_gbs = {
    description = "Block volume size (Always Free pool: 200 GB total)";
    type = "number";
    default = 100;
  };

  # Root compartment = the tenancy OCID, so default to it unless overridden.
  locals.compartment_ocid = "\${var.compartment_ocid != \"\" ? var.compartment_ocid : var.tenancy_ocid}";

  provider.oci = {
    region = lib.tf.ref "var.oci_region";
  };

  # ── Data sources ───────────────────────────────────────────────────────────
  # Availability domains in the (home) region — A1 instances are AD-scoped.
  data.oci_identity_availability_domains.ads = {
    compartment_id = lib.tf.ref "local.compartment_ocid";
  };

  # Newest Canonical Ubuntu image available for the A1 shape in this region.
  data.oci_core_images.ubuntu = {
    compartment_id = lib.tf.ref "local.compartment_ocid";
    operating_system = "Canonical Ubuntu";
    operating_system_version = "24.04";
    shape = "VM.Standard.A1.Flex";
  };

  # ── VCN ────────────────────────────────────────────────────────────────────
  resource.oci_core_vcn.main = {
    compartment_id = lib.tf.ref "local.compartment_ocid";
    cidr_blocks = [ "10.2.0.0/16" ];
    display_name = "nixos-oci";
    dns_label = "nixosoci";
  };

  resource.oci_core_internet_gateway.main = {
    compartment_id = lib.tf.ref "local.compartment_ocid";
    vcn_id = lib.tf.ref "oci_core_vcn.main.id";
    enabled = true;
    display_name = "nixos-oci-igw";
  };

  resource.oci_core_route_table.main = {
    compartment_id = lib.tf.ref "local.compartment_ocid";
    vcn_id = lib.tf.ref "oci_core_vcn.main.id";
    display_name = "nixos-oci-default-route";
    route_rules = [{
      destination = "0.0.0.0/0";
      destination_type = "CIDR_BLOCK";
      network_entity_id = lib.tf.ref "oci_core_internet_gateway.main.id";
    }];
  };

  resource.oci_core_security_list.main = {
    compartment_id = lib.tf.ref "local.compartment_ocid";
    vcn_id = lib.tf.ref "oci_core_vcn.main.id";
    display_name = "nixos-oci";

    ingress_security_rules = [
      {
        # SSH bootstrap for stage-2 (nixos-anywhere). Narrow after the host
        # joins the tailnet by restricting the source to the Tailscale CGNAT
        # range 100.64.0.0/10.
        protocol = "6"; # TCP
        source = "0.0.0.0/0";
        tcp_options = {
          min = 22;
          max = 22;
        };
      }
      {
        # Tailscale direct connections (WireGuard UDP).
        protocol = "17"; # UDP
        source = "0.0.0.0/0";
        udp_options = {
          min = 41641;
          max = 41641;
        };
      }
    ];

    egress_security_rules = [{
      protocol = "all";
      destination = "0.0.0.0/0";
    }];
  };

  resource.oci_core_subnet.main = {
    compartment_id = lib.tf.ref "local.compartment_ocid";
    vcn_id = lib.tf.ref "oci_core_vcn.main.id";
    cidr_block = "10.2.0.0/24";
    display_name = "nixos-oci";
    dns_label = "nixosoci";
    route_table_id = lib.tf.ref "oci_core_route_table.main.id";
    security_list_ids = [ "\${oci_core_security_list.main.id}" ];
    prohibit_public_ip_on_vnic = false;
  };

  # ── Instance (Ampere A1.Flex, always-free) ─────────────────────────────────
  resource.oci_core_instance.main = {
    availability_domain = lib.tf.ref "data.oci_identity_availability_domains.ads.availability_domains[0].name";
    compartment_id = lib.tf.ref "local.compartment_ocid";
    display_name = "nixos-oci";
    shape = "VM.Standard.A1.Flex";
    shape_config = {
      ocpus = lib.tf.ref "var.ocpus";
      memory_in_gbs = lib.tf.ref "var.memory_gbs";
    };
    source_details = {
      source_type = "image";
      source_id = lib.tf.ref "data.oci_core_images.ubuntu.images[0].id";
    };
    create_vnic_details = {
      assign_public_ip = true;
      subnet_id = lib.tf.ref "oci_core_subnet.main.id";
      display_name = "primary-vnic";
    };
    metadata = {
      ssh_authorized_keys = lib.tf.ref "var.ssh_pub_key";
    };
    preserve_boot_volume = false;
  };

  # ── Data volume (guarded inside the 200 GB free pool) ──────────────────────
  resource.oci_core_volume.data = {
    availability_domain = lib.tf.ref "data.oci_identity_availability_domains.ads.availability_domains[0].name";
    compartment_id = lib.tf.ref "local.compartment_ocid";
    display_name = "nixos-oci-data";
    size_in_gbs = lib.tf.ref "var.data_volume_gbs";
  };

  resource.oci_core_volume_attachment.data = {
    instance_id = lib.tf.ref "oci_core_instance.main.id";
    volume_id = lib.tf.ref "oci_core_volume.data.id";
    attachment_type = "paravirtualized";
  };

  # ── Outputs (consumed by stage-2 colmena/deploy-rs inventory) ──────────────
  output.public_ip = {
    value = lib.tf.ref "oci_core_instance.main.public_ip";
    description = "Public IP of the instance (for nixos-anywhere bootstrap)";
  };

  output.availability_domain = {
    value = lib.tf.ref "data.oci_identity_availability_domains.ads.availability_domains[0].name";
    description = "Availability domain the instance was launched in";
  };

  output.data_volume_id = {
    value = lib.tf.ref "oci_core_volume.data.id";
    description = "Block volume id (attach/mount in stage 2 for persistent service data)";
  };
}
