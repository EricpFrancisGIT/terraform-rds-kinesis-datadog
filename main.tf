terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.57"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

locals {
  name        = var.project_name
  common_tags = var.tags
}
