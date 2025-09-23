
data "aws_iam_policy_document" "pipes_assume" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["pipes.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "this" {
  name               = "${local.name}-role"
  assume_role_policy = data.aws_iam_policy_document.pipes_assume.json
  tags               = merge(local.tags, { Name = "${local.name}-role", Component = "iam-role" })
}


data "aws_iam_policy_document" "pipes_inline" {
  statement {
    sid       = "AllowStartStateMachine"
    actions   = ["states:StartExecution"]
    resources = [var.sfn_runner_arn]
  }

  statement {
    sid = "SqsSourcePermissions"
    actions = [
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes",
      "sqs:ChangeMessageVisibility"
    ]
    resources = [var.source_queue_arn]
  }
}

resource "aws_iam_role_policy" "pipes_inline" {
  role   = aws_iam_role.this.id
  policy = data.aws_iam_policy_document.pipes_inline.json
}


resource "aws_pipes_pipe" "this" {
  name     = local.name
  role_arn = aws_iam_role.this.arn

  source = var.source_queue_arn

  source_parameters {
    sqs_queue_parameters {
      batch_size = var.batch_size
    }
  }

  target = var.sfn_runner_arn

  target_parameters {
    step_function_state_machine_parameters {
      invocation_type = "FIRE_AND_FORGET"
    }
  }

  desired_state = "RUNNING"

  tags = merge(local.tags, { Name = "${local.name}-pipe", Component = "pipes" })
}
