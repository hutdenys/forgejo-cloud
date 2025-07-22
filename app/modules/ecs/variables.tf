variable "name_prefix" {
  description = "Name prefix for resources"
  type        = string
  default     = "forgejo"
}

variable "vpc_id" {
  description = "VPC ID where ECS will be created"
  type        = string
}

variable "subnets" {
  description = "List of subnet IDs for ECS service"
  type        = list(string)
}

variable "alb_security_group_id" {
  description = "Security group ID of the ALB"
  type        = string
}

variable "target_group_arn" {
  description = "ARN of the target group"
  type        = string
}

variable "container_name" {
  description = "Name of the container"
  type        = string
  default     = "forgejo"
}

variable "container_image" {
  description = "Docker image for the container"
  type        = string
}

variable "container_port" {
  description = "Port on which the container is listening"
  type        = number
  default     = 3000
}

variable "cpu" {
  description = "CPU units for the task"
  type        = string
  default     = "512"
}

variable "memory" {
  description = "Memory for the task"
  type        = string
  default     = "1024"
}

variable "desired_count" {
  description = "Desired number of tasks"
  type        = number
  default     = 1
}

variable "enable_execute_command" {
  description = "Enable ECS Exec for debugging"
  type        = bool
  default     = true
}

variable "assign_public_ip" {
  description = "Assign public IP to tasks"
  type        = bool
  default     = true
}

variable "efs_file_system_id" {
  description = "EFS file system ID"
  type        = string
  default     = null
}

variable "efs_access_point_id" {
  description = "EFS access point ID"
  type        = string
  default     = null
}

variable "mount_path" {
  description = "Container mount path for EFS"
  type        = string
  default     = "/data"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 7
}
