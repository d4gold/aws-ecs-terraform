output "alb_dns_name" {
  description = "Hit this in a browser to confirm the stack actually works."
  value       = aws_lb.this.dns_name
}

output "cluster_name" {
  value = aws_ecs_cluster.this.name
}

output "service_name" {
  value = aws_ecs_service.this.name
}

output "task_security_group_id" {
  description = "Feed this to the RDS module so the database accepts traffic only from tasks."
  value       = aws_security_group.task.id
}

output "task_role_arn" {
  value = aws_iam_role.task.arn
}

output "log_group_name" {
  value = aws_cloudwatch_log_group.this.name
}
