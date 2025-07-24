variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "availability_zone" {
  description = "Availability zone for EBS volume"
  type        = string
  default     = "us-east-1a"
}

variable "volume_size" {
  description = "Size of EBS volume in GB"
  type        = number
  default     = 10
}

variable "volume_type" {
  description = "EBS volume type"
  type        = string
  default     = "gp2"
}

variable "encrypted" {
  description = "Whether to encrypt EBS volume"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Additional tags for EBS volume"
  type        = map(string)
  default     = {}
}

variable "volume_name" {
  description = "Name tag for EBS volume"
  type        = string
  default     = "jenkins-home-persistent"
}
