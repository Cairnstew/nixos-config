variable "cloud_hosts" {
  type        = string
  description = "JSON map of host configs injected by the Nix flake"
}

variable "ssh_public_keys_aws" {
  type        = string
  description = "SSH public key for AWS hosts, injected from agenix by the flake"
  default     = ""
}