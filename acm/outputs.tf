output "certificate_arn" {
  description = "ARN of the ACM certificate"
  value       = aws_acm_certificate.forgejo.arn
}

output "certificate_domain_name" {
  description = "Domain name of the certificate"
  value       = aws_acm_certificate.forgejo.domain_name
}
