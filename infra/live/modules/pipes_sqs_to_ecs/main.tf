
data "aws_iam_policy_document" "assume" {
  statement {
    effect = "Allow"
    principals { 
        type = "Service"
        identifiers = ["pipes.amazonaws.com"] 
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "this" {
  name               = "${var.name}-role"
  assume_role_policy = data.aws_iam_policy_document.assume.json
}


data "aws_iam_policy_document" "inline" {
  statement {
    sid     = "AllowRunTaskOnCluster"
    actions = ["ecs:RunTask"]
    resources = [var.task_definition_arn]

    condition {
      test     = "ArnEquals"
      variable = "ecs:cluster"
      values   = [var.cluster_arn] 
    }
  }


  statement {
    sid     = "AllowPassRolesForTasks"
    actions = ["iam:PassRole"]
    resources = compact([
      var.execution_role_arn,
      var.task_role_arn, 
    ])
    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["ecs-tasks.amazonaws.com"]
    }
  }

 
  statement {
    sid     = "AllowDescribeForSanity"
    actions = [
      "ecs:DescribeClusters",
      "ecs:DescribeTaskDefinition"
    ]
    resources = ["*"]
  }

 
  statement {
    sid     = "SQSSourcePermissions"
    actions = [
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes",
      "sqs:ChangeMessageVisibility"
    ]
    resources = [var.source_queue_arn]
  }
}


resource "aws_iam_role_policy" "inline" {
  role   = aws_iam_role.this.id
  policy = data.aws_iam_policy_document.inline.json
}

resource "aws_pipes_pipe" "this" {
  name     = var.name
  role_arn = aws_iam_role.this.arn

  source = var.source_queue_arn

  source_parameters {
    sqs_queue_parameters {
      batch_size = var.batch_size
    }
  }

  target = var.cluster_arn

  target_parameters {
    ecs_task_parameters {
      task_definition_arn = var.task_definition_arn
      launch_type         = "FARGATE"
      task_count          = 1
      network_configuration {
        aws_vpc_configuration {
          subnets          = var.subnet_ids
          security_groups  = var.security_group_ids
          assign_public_ip = var.assign_public_ip ? "ENABLED" : "DISABLED"
        }
      }
      overrides {
        container_override {
          name = var.container_name
          cpu                = 1024
          memory             = 2048
          memory_reservation = 1024

          environment {
            name  = "PAYLOAD"
            value = "$.body"
          }
        }
      }
    }
  }

  desired_state = "RUNNING"
}
