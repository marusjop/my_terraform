terraform {
  required_version = ">= 1.0.0"
  # backend "local" {
  #   path = "mystate/terraform.tfstate"
  # }
  backend "s3" {
    bucket = "marekj-bucket"
    key    = "prod/aws_infra"
    region = "eu-north-1"

    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
  required_providers {
    aws = {
      source = "hashicorp/aws"
      # version = "~> 3.0"
    }
    http = {
      source = "hashicorp/http"
      #  version = "2.1.0"
    }
    random = {
      source = "hashicorp/random"
      # version = "3.1.0"
    }
    local = {
      source = "hashicorp/local"
      # version = "2.1.0"      
    }
    tls = {
      source = "hashicorp/tls"
      # version = "3.1.0"
    }
  }
}

provider "aws" {
  region = "eu-north-1"
  default_tags {
    tags = {
      environment = terraform.workspace
    }
  }
}

