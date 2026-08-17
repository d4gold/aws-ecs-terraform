# ---------------------------------------------------------------------------
# Remote state.
#
# Fill in the bucket name from the bootstrap output, then run:
#   terraform init -migrate-state
#
# use_lockfile = true is S3-native state locking (Terraform 1.10+). It
# replaces the old DynamoDB lock table entirely -- one less resource to
# manage, and no separate table to pay for.
# ---------------------------------------------------------------------------

# RUN bootstrap/ FIRST. Until the state bucket exists, leave this whole
# block commented out -- envs/dev will use local state and init fine.
#
# After bootstrap applies, uncomment, paste the bucket name from its
# state_bucket output, then run: terraform init -migrate-state
#
# terraform {
#   backend "s3" {
#     bucket       = "PASTE-BUCKET-NAME-HERE"
#     key          = "envs/dev/terraform.tfstate"
#     region       = "us-east-1"
#     encrypt      = true
#     use_lockfile = true
#   }
# }
