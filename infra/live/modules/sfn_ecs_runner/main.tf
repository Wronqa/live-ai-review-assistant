data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

data "aws_iam_policy_document" "sfn_assume" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["states.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "sfn_role" {
  name               = "${local.name}-role"
  assume_role_policy = data.aws_iam_policy_document.sfn_assume.json
  tags               = merge(local.tags, { Name = "${local.name}-role", Component = "iam-role" })
}

data "aws_iam_policy_document" "sfn_policy" {
  statement {
    sid       = "EcsRunTask"
    actions   = ["ecs:RunTask"]
    resources = [var.task_definition_arn]

    condition {
      test     = "ArnEquals"
      variable = "ecs:cluster"
      values   = [var.cluster_arn]
    }
  }

  statement {
    sid       = "EcsDescribe"
    actions   = ["ecs:DescribeTasks"]
    resources = ["arn:aws:ecs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:task/${var.cluster_name}/*"]
  }

  statement {
    sid       = "PassRolesToEcs"
    actions   = ["iam:PassRole"]
    resources = compact([var.task_execution_role_arn, var.task_role_arn])
    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["ecs-tasks.amazonaws.com"]
    }
  }

  statement {
    sid       = "EventsForSync"
    actions   = ["events:PutRule", "events:PutTargets", "events:DescribeRule"]
    resources = ["arn:aws:events:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:rule/StepFunctionsGetEventsForECSTaskRule"]
  }

  statement {
    sid       = "SendToQueue"
    actions   = ["sqs:SendMessage"]
    resources = [local.target_sqs_arn]
  }
}

resource "aws_iam_policy" "sfn_policy" {
  name   = "${local.name}-sfn-policy"
  policy = data.aws_iam_policy_document.sfn_policy.json
}

resource "aws_iam_role_policy_attachment" "sfn_attach" {
  role       = aws_iam_role.sfn_role.name
  policy_arn = aws_iam_policy.sfn_policy.arn
}

resource "aws_sfn_state_machine" "ecs_runner" {
  name       = local.name
  role_arn   = aws_iam_role.sfn_role.arn
  definition = local.sfn_definition
  tags       = merge(local.tags, { Name = "${local.name}-sfn", Component = "sfn" })
}

