output "alb_dns_name" {
  description = "Hit this in a browser to confirm the stack actually works."
  value       = aws_lb.main.dns_name
}

output "cluster_name" {
  description = "Name of the ECS cluster."
  value       = aws_ecs_cluster.main.name
}

output "service_name" {
  description = "Name of the ECS service."
  value       = aws_ecs_service.main.name
}

output "task_security_group_id" {
  description = "Feed this to the RDS module so the database accepts traffic only from tasks."
  value       = aws_security_group.task.id
}

output "task_role_arn" {
  description = "ARN of the task role assumed by application code."
  value       = aws_iam_role.task.arn
}

output "log_group_name" {
  description = "CloudWatch log group receiving container logs."
  value       = aws_cloudwatch_log_group.main.name
}
