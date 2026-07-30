# The FIRST resource in the whole stack, on purpose: a spend tripwire.
# Before we create anything that could cost money, we create the thing that
# emails us if money starts being spent unexpectedly.
#
# Two alerts on one budget:
#   1. ACTUAL > 80%  — "you've already spent $4 this month, pay attention."
#   2. FORECASTED > 100% — "at this rate you're on track to blow past $5,"
#      which warns you BEFORE the money is actually gone.
resource "aws_budgets_budget" "monthly" {
  name         = "${var.project}-monthly"
  budget_type  = "COST"
  limit_amount = var.budget_limit_usd
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  # ACTUAL-spend tripwires at roughly $1, $2, $3, $4, $5 (20/40/60/80/100% of
  # the $5 budget). You hear about ANY real spending almost immediately, not
  # just when it's nearly too late.
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 20 # ~$1
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.alert_email]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 40 # ~$2
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.alert_email]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 60 # ~$3
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.alert_email]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80 # ~$4
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.alert_email]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100 # $5 reached
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.alert_email]
  }

  # FORECASTED: warns when AWS PROJECTS you'll exceed $5 by month end — before
  # the money is actually gone.
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = [var.alert_email]
  }
}
