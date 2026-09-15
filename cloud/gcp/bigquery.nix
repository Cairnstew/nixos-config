# cloud/gcp/bigquery.nix — BigQuery datasets & tables (terranix module)
#
# Defines configurable BigQuery resources with sensible free-tier defaults.
# Imported by cloud/gcp/default.nix and optionally extended via extraArgs.
#
# Usage from NixOS modules (via flake-parts bridge):
#   my.cloud.gcp.bigquery.datasets = {
#     analytics = { description = "Analytics data"; };
#     logs = { description = "Application logs"; };
#   };
#
# Usage directly in terranix:
#   modules = [ ../../cloud/gcp ../../cloud/gcp/bigquery.nix ];
#   extraBigqueryDatasets = { sandbox = { description = "Dev sandbox"; }; };
{ lib, config, ... }:

let
  # Apply defaults to a dataset config
  applyDatasetDefaults = name: dsCfg: {
    dataset_id = name;
    friendly_name =
      if dsCfg.friendly_name != "" then dsCfg.friendly_name
      else lib.replaceStrings [ "-" "_" ] [ " " " " ] (lib.capitalize name);
    description =
      if dsCfg.description != "" then dsCfg.description
      else "BigQuery dataset: ${name}";
    location =
      if dsCfg.location != "" then dsCfg.location
      else lib.tf.ref "var.region";
    project = lib.tf.ref "var.project";
    inherit (dsCfg) max_time_travel_hours delete_contents_on_destroy;
    # Merge default labels
    labels = { managed-by = "terranix"; } // dsCfg.labels;
  };

  # Apply defaults to a table config
  applyTableDefaults = datasetName: tableName: tblCfg: {
    dataset_id = datasetName;
    table_id = tableName;
    project = lib.tf.ref "var.project";
    inherit (tblCfg) deletion_protection time_partitioning;
    # Merge default labels
    labels = { managed-by = "terranix"; } // tblCfg.labels;
  };

  # Collect all datasets from config
  datasets = config.bigquery.datasets // (config.extraBigqueryDatasets or { });

  # Collect all tables from config (keyed as "dataset.table")
  tables = lib.concatMapAttrs
    (datasetName: dsCfg:
      lib.concatMapAttrs
        (tableName: tblCfg: {
          "${datasetName}.${tableName}" = applyTableDefaults datasetName tableName tblCfg;
        })
        (dsCfg.tables or { })
    )
    datasets;
in
{
  # ── Options ──────────────────────────────────────────────────────────────
  options.bigquery = {
    datasets = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          dataset_id = lib.mkOption {
            type = lib.types.str;
            description = "Dataset ID (defaults to attr name)";
          };
          friendly_name = lib.mkOption {
            type = lib.types.str;
            default = "";
            description = "Human-readable name";
          };
          description = lib.mkOption {
            type = lib.types.str;
            default = "";
            description = "Dataset description";
          };
          location = lib.mkOption {
            type = lib.types.str;
            default = "";
            description = "GCP region for the dataset";
          };
          max_time_travel_hours = lib.mkOption {
            type = lib.types.int;
            default = 48;
            description = "Time travel window (min 48, max 168)";
          };
          delete_contents_on_destroy = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Delete data when dataset is destroyed";
          };
          labels = lib.mkOption {
            type = lib.types.attrsOf lib.types.str;
            default = { };
            description = "Resource labels";
          };
          tables = lib.mkOption {
            type = lib.types.attrsOf (lib.types.submodule {
              options = {
                table_id = lib.mkOption {
                  type = lib.types.str;
                  description = "Table ID (defaults to attr name)";
                };
                deletion_protection = lib.mkOption {
                  type = lib.types.bool;
                  default = true;
                  description = "Prevent accidental deletion";
                };
                time_partitioning = lib.mkOption {
                  type = lib.types.attrsOf lib.types.anything;
                  default = { type = "DAY"; };
                  description = "Time partitioning config";
                };
                labels = lib.mkOption {
                  type = lib.types.attrsOf lib.types.str;
                  default = { };
                  description = "Table labels";
                };
              };
            });
            default = { };
            description = "Tables in this dataset";
          };
        };
      });
      default = { };
      description = "BigQuery datasets to create";
    };
  };

  # ── External override point (for terranix extraArgs) ──────────────────────
  options.extraBigqueryDatasets = lib.mkOption {
    type = lib.types.attrsOf lib.types.anything;
    default = { };
    description = "Additional datasets merged into bigquery.datasets (via extraArgs)";
  };

  # ── Terraform resources ──────────────────────────────────────────────────
  config = {
    resource.google_bigquery_dataset = lib.mapAttrs
      (name: dsCfg:
        applyDatasetDefaults name dsCfg
      )
      datasets;

    resource.google_bigquery_table = lib.mapAttrs (_: tblCfg: tblCfg) tables;

    output.bigquery_datasets = {
      value = lib.mapAttrs (_: dsCfg: dsCfg.dataset_id) datasets;
      description = "Created BigQuery dataset IDs";
    };

    output.bigquery_tables = {
      value = lib.mapAttrs (_: tblCfg: "${tblCfg.dataset_id}.${tblCfg.table_id}") tables;
      description = "Created BigQuery tables (dataset.table)";
    };
  };
}
