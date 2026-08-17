# ---------------------------------------------------------------------------
# Cost guardrail.
#
# Lives in bootstrap because it has to outlive envs/dev -- a budget destroyed
# alongside the thing it watches is not a guardrail.
#
# This alerts, it does not cap. AWS keeps billing past the threshold and cost
# data lags up to ~24h. `terraform destroy` remains the real control.
#
#
# block below adopts it rather than recreating it, so coverage is never
# interrupted. Remove the import block once it has been applied.
# ---------------------------------------------------------------------------


resource "aws_budgets_budget" "monthly_cost" {
  name         = var.budget_name
  budget_type  = "COST"
  limit_amount = var.budget_limit_usd
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  # Two actual thresholds and a forecast. The forecast is the useful one --
  # it fires before the money is spent rather than after.
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 20
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.budget_notification_email]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.budget_notification_email]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = [var.budget_notification_email]
  }
}
