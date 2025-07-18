output "ecs_service_name" {
  value = aws_ecs_service.forgejo.name
}

output "task_definition_arn" {
  value = aws_ecs_task_definition.forgejo.arn
}

output "alb_dns_name" {
  value       = module.alb.dns_name
  description = "The DNS name of the ALB"
}
