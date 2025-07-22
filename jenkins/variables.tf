variable "instance_type" {
  description = "EC2 instance type for Jenkins"
  type        = string
  default     = "t3.small"
}

variable "allowed_ip_cidr" {
  description = "Your IP address in CIDR format (e.g., 203.0.113.15/32)"
  type        = string
}

variable "key_pair_name" {
  description = "EC2 Key Pair name for SSH access"
  type        = string
}

variable "jenkins_home_size" {
  description = "Size of EBS volume for Jenkins home directory (GB)"
  type        = number
  default     = 5
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}
