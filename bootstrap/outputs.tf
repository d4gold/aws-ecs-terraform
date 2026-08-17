output "state_bucket" {
  description = "Put this in the backend block of every other config."
  value       = aws_s3_bucket.state.id
}

output "github_actions_role_arn" {
  description = "Set as AWS_ROLE_ARN in GitHub repo variables."
  value       = try(aws_iam_role.github_actions[0].arn, null)
}

output "backend_config" {
  description = "Copy this into envs/*/backend.tf"
  value       = <<-EOT
    terraform {
      backend "s3" {
        bucket       = "${aws_s3_bucket.state.id}"
        key          = "envs/dev/terraform.tfstate"
        region       = "${var.region}"
        encrypt      = true
        use_lockfile = true
      }
    }
  EOT
}
