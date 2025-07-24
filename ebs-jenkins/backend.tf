terraform {
  backend "s3" {
    bucket = "my-tf-state-bucket535845769543"
    key    = "ebs-jenkins/terraform.tfstate"
    region = "us-east-1"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  required_version = ">= 1.0"
}
