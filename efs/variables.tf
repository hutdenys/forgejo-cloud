variable "name" {
  description = "Name prefix for resources"
  type        = string
}

variable "creation_token" {
  description = "Unique token for EFS creation"
  type        = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "ecs_security_group_id" {
  type = string
}
