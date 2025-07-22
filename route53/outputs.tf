output "forgejo_fqdn" {
  description = "Fully qualified domain name for Forgejo application"
  value       = aws_route53_record.forgejo.fqdn
}

output "forgejo_domain" {
  description = "Domain name for Forgejo application"
  value       = var.domain_name
}

output "jenkins_fqdn" {
  description = "Fully qualified domain name for Jenkins (if enabled)"
  value       = var.enable_jenkins_dns ? aws_route53_record.jenkins[0].fqdn : null
}

output "jenkins_domain" {
  description = "Domain name for Jenkins (if enabled)"
  value       = var.enable_jenkins_dns ? "${var.jenkins_subdomain}.${var.domain_name}" : null
}

output "hosted_zone_id" {
  description = "Route 53 hosted zone ID"
  value       = local.hosted_zone_id
}

output "hosted_zone_name" {
  description = "Route 53 hosted zone name"
  value       = var.domain_name
}

output "name_servers" {
  description = "Name servers for the hosted zone (use these at your domain registrar)"
  value       = var.create_hosted_zone ? aws_route53_zone.main[0].name_servers : null
}
