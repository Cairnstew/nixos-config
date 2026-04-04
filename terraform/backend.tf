terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  # Local state for now — to migrate to S3 later:
  # backend "s3" {
  #   bucket         = "my-tofu-state"
  #   key            = "nixos/terraform.tfstate"
  #   region         = "eu-west-1"
  #   dynamodb_table = "tofu-lock"
  # }
}