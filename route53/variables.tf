variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "domain_name" {
  description = "The domain name for the Route 53 hosted zone"
  type        = string
}

variable "create_hosted_zone" {
  description = "Create new hosted zone (true) or use existing (false)"
  type        = bool
  default     = true
}

variable "jenkins_subdomain" {
  description = "Subdomain for Jenkins CI/CD (e.g., jenkins.example.com)"
  type        = string
  default     = "jenkins"
}

variable "state_bucket" {
  description = "S3 bucket name for Terraform state"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "prod"
}

variable "enable_jenkins_dns" {
  description = "Enable DNS record for Jenkins"
  type        = bool
  default     = true
}

variable "enable_www_redirect" {
  description = "Enable www subdomain redirect"
  type        = bool
  default     = false
}

variable "enable_health_checks" {
  description = "Enable Route 53 health checks"
  type        = bool
  default     = true
}

variable "sns_topic_arn" {
  description = "SNS topic ARN for health check alarms (optional)"
  type        = string
  default     = ""
}
