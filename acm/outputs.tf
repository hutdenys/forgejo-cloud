output "certificate_arn" {
  description = "ARN of the ACM certificate"
  value       = data.aws_acm_certificate.forgejo.arn
}

output "certificate_domain_name" {
  description = "Domain name of the certificate"
  value       = data.aws_acm_certificate.forgejo.domain
}
