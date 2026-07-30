# AUTOMATED BRAKE — the nearest thing to an automatic spending cap.
#
# When ACTUAL spend hits 100% of the budget ($5), AWS Budgets automatically
# attaches a restrictive IAM policy to the deploy user that BLOCKS creating new
# expensive resources — while still allowing describe/list/DELETE, so you can
# always see what exists and tear it down.
#
# Honest limitations (why this is a brake, not a guaranteed hard cap):
#   - It triggers on ACTUAL spend, which AWS meters with a delay (often hours),
#     so it is NOT instantaneous.
#   - It only restricts NEW resource creation; things already running keep
#     running (and keep costing) until you delete them.
#   - It restricts one IAM user, not the whole account.
# The truly bulletproof control remains: `terraform destroy` when idle.

# ---- The policy that gets APPLIED when the budget is breached ----
# Deny the common ways to accidentally run up a bill. Deletes/reads are NOT
# denied, so you can still investigate and tear down.
resource "aws_iam_policy" "cost_brake" {
  name        = "${var.project}-cost-brake"
  description = "Applied by AWS Budgets at 100% spend: blocks new billable resources."

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyExpensiveCreates"
        Effect = "Deny"
        Action = [
          "ec2:RunInstances",
          "ec2:CreateNatGateway",
          "rds:CreateDBInstance",
          "rds:CreateDBCluster",
          "rds:RestoreDBClusterFromSnapshot",
          "rds:RestoreDBClusterToPointInTime",
          "elasticloadbalancing:CreateLoadBalancer",
          "eks:CreateCluster",
          "ecs:CreateCluster",
          "ecs:CreateService",
          "ecs:RunTask",
          "redshift:CreateCluster",
          "elasticache:CreateCacheCluster",
          "sagemaker:CreateNotebookInstance",
          "sagemaker:CreateEndpoint"
        ]
        Resource = "*"
      }
    ]
  })
}

# ---- The role AWS Budgets assumes to perform the action ----
resource "aws_iam_role" "budgets_action" {
  name = "${var.project}-budgets-action"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "budgets.amazonaws.com" }
        Action    = "sts:AssumeRole"
      }
    ]
  })
}

# Lets that role attach the brake policy to the target user when triggered.
resource "aws_iam_role_policy" "budgets_action" {
  name = "${var.project}-budgets-action"
  role = aws_iam_role.budgets_action.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["iam:AttachUserPolicy", "iam:DetachUserPolicy"]
        Resource = "*"
      }
    ]
  })
}

# ---- The budget action itself ----
resource "aws_budgets_budget_action" "brake" {
  budget_name        = aws_budgets_budget.monthly.name
  action_type        = "APPLY_IAM_POLICY"
  approval_model     = "AUTOMATIC" # fire without waiting for you to click
  notification_type  = "ACTUAL"
  execution_role_arn = aws_iam_role.budgets_action.arn

  action_threshold {
    action_threshold_type  = "PERCENTAGE"
    action_threshold_value = 100 # at $5 actual
  }

  definition {
    iam_action_definition {
      policy_arn = aws_iam_policy.cost_brake.arn
      users      = [var.budget_action_target_user]
    }
  }

  subscriber {
    address           = var.alert_email
    subscription_type = "EMAIL"
  }
}
