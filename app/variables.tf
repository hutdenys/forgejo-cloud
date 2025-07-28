variable "forgejo_image" {
  description = "Docker image for Forgejo"
  type        = string
}

variable "db_name" {
  type = string
}

variable "db_username" {
  type = string
}

variable "db_password" {
  type      = string
  sensitive = true
}

variable "jenkins_domain" {
  description = "Jenkins subdomain (e.g., jenkins.example.com)"
  type        = string
  default     = ""
}
