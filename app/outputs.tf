output "ecs_service_name" {
  description = "Name of the ECS service"
  value       = module.ecs.ecs_service_name
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = module.ecs.ecs_cluster_name
}

output "task_definition_arn" {
  description = "ARN of the task definition"
  value       = module.ecs.task_definition_arn
}

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = module.elb.alb_dns_name
}

output "alb_zone_id" {
  description = "Zone ID of the Application Load Balancer"
  value       = module.elb.alb_zone_id
}

output "ecs_security_group_id" {
  description = "ID of the ECS security group"
  value       = module.ecs.ecs_security_group_id
}
