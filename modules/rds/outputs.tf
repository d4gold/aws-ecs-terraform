output "endpoint" {
  description = "host:port"
  value       = aws_db_instance.main.endpoint
}

output "address" {
  description = "Hostname of the database instance, without the port."
  value       = aws_db_instance.main.address
}

output "port" {
  description = "Port the database listens on."
  value       = aws_db_instance.main.port
}

output "security_group_id" {
  description = "ID of the database security group."
  value       = aws_security_group.main.id
}

output "secret_arn" {
  description = "Secrets Manager ARN holding the master credentials."
  value       = aws_secretsmanager_secret.db.arn
}

output "identifier" {
  description = "RDS instance identifier."
  value       = aws_db_instance.main.identifier
}
