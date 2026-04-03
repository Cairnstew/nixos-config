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

resource "aws_security_group" "nixos" {
  name = "nixos-vms"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}