variable "name_prefix" {
  description = "Name prefix for resources"
  type        = string
  default     = "forgejo"
}

variable "vpc_id" {
  description = "VPC ID where ALB will be created"
  type        = string
}

variable "subnets" {
  description = "List of subnet IDs for ALB"
  type        = list(string)
}

variable "certificate_arn" {
  description = "ARN of the SSL certificate"
  type        = string
}

variable "container_port" {
  description = "Port on which the container is listening"
  type        = number
  default     = 3000
}

variable "target_group_prefix" {
  description = "Prefix for target group name"
  type        = string
  default     = "fgj"
}

variable "health_check" {
  description = "Health check configuration for target group"
  type = object({
    enabled             = bool
    path                = string
    healthy_threshold   = number
    unhealthy_threshold = number
    timeout             = number
    interval            = number
    matcher             = string
  })
  default = {
    enabled             = true
    path                = "/fake"
    healthy_threshold   = 2
    unhealthy_threshold = 10
    timeout             = 2
    interval            = 300
    matcher             = "404"
  }
}

variable "alb_security_group_id" {
  description = "Security Group ID for ALB"
  type        = string
}

variable "jenkins_domain" {
  description = "Jenkins subdomain (e.g., jenkins.example.com)"
  type        = string
  default     = ""
}
