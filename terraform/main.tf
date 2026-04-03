terraform {
  required_providers {
    aws   = { source = "hashicorp/aws",   version = "~> 5.0" }
    tls   = { source = "hashicorp/tls",   version = "~> 4.0" }
    local = { source = "hashicorp/local", version = "~> 2.0" }
  }
}

provider "aws" {
  region = "eu-west-1"
}

# ---------------------------------------------------------------------------
# SSH key pair
# ---------------------------------------------------------------------------
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

# ---------------------------------------------------------------------------
# Security group
# ---------------------------------------------------------------------------
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

# ---------------------------------------------------------------------------
# NixOS AMI lookup
# Uses the official NixOS community AMIs (owner: 080433136561).
# No local Nix build or flake_root needed — just pick the release version.
# ---------------------------------------------------------------------------
locals {
  nixos_releases = distinct([for host in var.cloud_hosts : host.nixos_release])
}

data "aws_ami" "nixos" {
  for_each = toset(local.nixos_releases)

  most_recent = true
  owners      = ["080433136561"] # NixOS community AWS account

  filter {
    name   = "name"
    values = ["nixos/${each.value}.*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ---------------------------------------------------------------------------
# EC2 instances
# ---------------------------------------------------------------------------
resource "aws_instance" "cloud_hosts" {
  for_each = var.cloud_hosts

  ami                         = data.aws_ami.nixos[each.value.nixos_release].id
  instance_type               = each.value.instance_type
  key_name                    = aws_key_pair.deployer.key_name
  associate_public_ip_address = true

  vpc_security_group_ids = [aws_security_group.nixos.id]

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  tags = {
    Name = each.key
  }

  depends_on = [local_sensitive_file.deployer_ssh_key]
}