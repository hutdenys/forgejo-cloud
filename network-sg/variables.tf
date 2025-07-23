variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "project_name" {
  description = "Name to prefix resources with"
  type        = string
}

variable "environment" {
  description = "Environment (e.g. dev, prod)"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "azs" {
  description = "Availability zones"
  type        = list(string)
}

variable "public_subnets" {
  description = "Public subnet CIDRs"
  type        = list(string)
}

variable "private_subnets" {
  description = "Private subnet CIDRs"
  type        = list(string)
}

variable "enable_nat_gateway" {
  description = "Enable NAT Gateway"
  type        = bool
  default     = false
}

variable "ecs_container_port" {
  description = "Port on which the ECS container listens"
  type        = number
  default     = 3000
}

variable "jenkins_allowed_ip_cidr" {
  description = "CIDR block allowed to access Jenkins"
  type        = string
}
