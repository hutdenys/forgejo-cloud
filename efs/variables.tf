variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "state_bucket" {
  description = "S3 bucket name for Terraform state"
  type        = string
}

variable "name" {
  description = "Name prefix for resources"
  type        = string
}

variable "creation_token" {
  description = "Unique token for EFS creation"
  type        = string
}
