variable "name" {
  type        = string
  description = "Host name, used to tag and identify resources"
}

variable "instance_type" {
  type        = string
  description = "EC2 instance type"
  default     = "t3.micro"
}

variable "nixos_release" {
  type        = string
  description = "NixOS release for AMI lookup"
  default     = "24.11"
}

variable "region" {
  type        = string
  description = "AWS region to deploy into"
}

variable "ssh_public_key" {
  type        = string
  description = "SSH public key to provision on the instance"
  default     = ""  # override per-host or via tfvars
}