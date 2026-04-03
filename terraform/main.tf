terraform {
  required_providers {
    aws      = { source = "hashicorp/aws",      version = "~> 5.0" }
    tls      = { source = "hashicorp/tls",      version = "~> 4.0" }
    local    = { source = "hashicorp/local",    version = "~> 2.0" }
    external = { source = "hashicorp/external", version = "~> 2.0" }
    null     = { source = "hashicorp/null",     version = "~> 3.0" }
  }
}

provider "aws" {
  region = "eu-west-1"
}

# Generate or use existing SSH key pair
resource "tls_private_key" "deployer" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "deployer" {
  key_name   = "nixos-deployer"
  public_key = tls_private_key.deployer.public_key_openssh
}

resource "local_sensitive_file" "deployer_ssh_key" {
  content         = tls_private_key.deployer.private_key_pem
  filename        = "${path.module}/id_deployer.pem"
  file_permission = "0600"
}

# Security group for NixOS instances
resource "aws_security_group" "nixos" {
  name        = "nixos-vms"
  description = "Security group for NixOS VMs"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SSH access"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name = "nixos-security-group"
  }
}

# Build NixOS AMI for each release version
locals {
  nixos_releases = distinct([for host in var.cloud_hosts : host.nixos_release])
}

module "nixos_image" {
  for_each = toset(local.nixos_releases)

  source = "git::https://github.com/nix-community/terraform-nixos.git?ref=master//aws_image_nixos"

  flake_url = "file://${var.flake_root}"
  release   = each.value
}

# Deploy EC2 instances for each cloud host
resource "aws_instance" "cloud_hosts" {
  for_each = var.cloud_hosts

  ami           = module.nixos_image[each.value.nixos_release].ami
  instance_type = each.value.instance_type
  key_name      = aws_key_pair.deployer.key_name

  vpc_security_group_ids = [aws_security_group.nixos.id]

  tags = {
    Name = each.key
  }

  depends_on = [local_sensitive_file.deployer_ssh_key]
}