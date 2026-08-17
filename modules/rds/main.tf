locals {
  tags = merge(var.tags, { Module = "rds" })
}

# ---------------------------------------------------------------------------
# Security group.
#
# Ingress on the database port comes only from the security group IDs passed
# in -- in practice, the ECS task security group. There is no CIDR rule and
# no public access. The database is not reachable from the internet by any
# path: no public IP, no route, no security group rule.
# ---------------------------------------------------------------------------

resource "aws_security_group" "this" {
  name        = "${var.name}-rds"
  description = "Postgres access from application security groups only"
  vpc_id      = var.vpc_id
  tags        = merge(local.tags, { Name = "${var.name}-rds" })
}

resource "aws_vpc_security_group_ingress_rule" "from_apps" {
  for_each = var.allowed_security_group_ids

  security_group_id            = aws_security_group.this.id
  description                  = "Postgres from ${each.key}"
  referenced_security_group_id = each.value
  from_port                    = var.port
  to_port                      = var.port
  ip_protocol                  = "tcp"
}

# ---------------------------------------------------------------------------
# Subnet group. Spans private subnets in at least two AZs -- this is what
# makes Multi-AZ failover possible at all. RDS will refuse to create a
# Multi-AZ instance in a single-AZ subnet group.
# ---------------------------------------------------------------------------

resource "aws_db_subnet_group" "this" {
  name       = "${var.name}-db"
  subnet_ids = var.private_subnet_ids
  tags       = merge(local.tags, { Name = "${var.name}-db" })
}

# ---------------------------------------------------------------------------
# Parameter group.
#
# Worth creating even when empty: you cannot modify the default group, so
# without your own you have no way to tune anything later without a
# disruptive migration. log_min_duration_statement is the single most
# useful default to set -- it logs slow queries without logging everything.
# ---------------------------------------------------------------------------

resource "aws_db_parameter_group" "this" {
  name   = "${var.name}-pg"
  family = var.parameter_group_family

  parameter {
    name  = "log_min_duration_statement"
    value = "1000" # log anything slower than 1 second
  }

  parameter {
    name  = "log_connections"
    value = "1"
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = local.tags
}

# ---------------------------------------------------------------------------
# Credentials.
#
# Generated, then stored in Secrets Manager. Never a hardcoded password and
# never a plaintext variable. Note that the password still lands in Terraform
# state -- which is why state belongs in an encrypted S3 bucket with
# restricted access, not on a laptop. That tradeoff is worth naming out loud.
#
# In production the stronger option is manage_master_user_password = true,
# which hands rotation to RDS entirely and keeps the value out of state.
# ---------------------------------------------------------------------------

resource "random_password" "master" {
  length  = 32
  special = true
  # Characters RDS rejects in a master password.
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_secretsmanager_secret" "db" {
  name                    = "${var.name}/rds/master"
  recovery_window_in_days = 0 # non-production: allow immediate delete
  tags                    = local.tags
}

resource "aws_secretsmanager_secret_version" "db" {
  secret_id = aws_secretsmanager_secret.db.id
  secret_string = jsonencode({
    username = var.master_username
    password = random_password.master.result
    engine   = "postgres"
    host     = aws_db_instance.this.address
    port     = var.port
    dbname   = var.database_name
  })
}

# ---------------------------------------------------------------------------
# The instance
# ---------------------------------------------------------------------------

resource "aws_db_instance" "this" {
  identifier = "${var.name}-db"

  engine         = "postgres"
  engine_version = var.engine_version
  instance_class = var.instance_class

  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage # enables storage autoscaling
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name  = var.database_name
  username = var.master_username
  password = random_password.master.result
  port     = var.port

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.this.id]
  parameter_group_name   = aws_db_parameter_group.this.name
  publicly_accessible    = false

  multi_az = var.multi_az

  # Backups. Retention of 0 disables automated backups entirely, which also
  # disables point-in-time recovery. Never 0 in production.
  backup_retention_period = var.backup_retention_period
  backup_window           = "07:00-08:00" # UTC, ahead of the maintenance window
  maintenance_window      = "Mon:08:30-Mon:09:30"
  copy_tags_to_snapshot   = true

  performance_insights_enabled    = var.performance_insights_enabled
  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  auto_minor_version_upgrade = true
  deletion_protection        = var.deletion_protection

  # Development settings. Both should be inverted in production:
  # you want a final snapshot, and you do not want silent destroys.
  skip_final_snapshot = var.skip_final_snapshot
  apply_immediately   = var.apply_immediately

  tags = merge(local.tags, { Name = "${var.name}-db" })

  lifecycle {
    ignore_changes = [engine_version] # let minor version upgrades happen
  }
}

# ---------------------------------------------------------------------------
# A minimum-viable alarm. Storage exhaustion is the failure mode that takes
# a database fully offline with no warning, so it is the first alarm worth
# having on any Postgres instance.
# ---------------------------------------------------------------------------

resource "aws_cloudwatch_metric_alarm" "free_storage" {
  count = var.create_alarms ? 1 : 0

  alarm_name          = "${var.name}-rds-low-storage"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = var.free_storage_alarm_bytes
  alarm_description   = "Free storage below threshold on ${var.name}-db"
  treat_missing_data  = "breaching"

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.this.identifier
  }

  tags = local.tags
}

resource "aws_cloudwatch_metric_alarm" "cpu" {
  count = var.create_alarms ? 1 : 0

  alarm_name          = "${var.name}-rds-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "Sustained high CPU on ${var.name}-db"
  treat_missing_data  = "notBreaching"

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.this.identifier
  }

  tags = local.tags
}
