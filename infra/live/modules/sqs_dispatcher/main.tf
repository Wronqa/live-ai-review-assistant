data "archive_file" "zip" {
  type        = "zip"
  source_dir  = var.lambda_src_dir
  output_path = "${path.module}/.tmp/${var.name}.zip"
}

resource "aws_cloudwatch_log_group" "lg" {
  name              = "/aws/lambda/${var.name}"
  retention_in_days = 7
  tags = var.tags
}

resource "aws_iam_role" "role" {
  name = "${var.name}-role"
  assume_role_policy = jsonencode({
    Version="2012-10-17",
    Statement=[{ Effect="Allow", Principal={ Service="lambda.amazonaws.com" }, Action="sts:AssumeRole" }]
  })
  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "logs" {
  role       = aws_iam_role.role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_policy" "ecs_run" {
  name = "${var.name}-ecs-run"
  policy = jsonencode({
    Version="2012-10-17",
    Statement=[
      { Effect="Allow", Action=["ecs:RunTask"], Resource=var.task_def_arn },
      { Effect="Allow", Action=["iam:PassRole"], Resource=[ var.task_role_arn, var.execution_role_arn ],
        Condition={ StringLike={ "iam:PassedToService": "ecs-tasks.amazonaws.com" } } },
      { Effect="Allow", Action=["ec2:DescribeSubnets","ec2:DescribeSecurityGroups","ec2:DescribeNetworkInterfaces"], Resource="*" }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_run_attach" {
  role       = aws_iam_role.role.name
  policy_arn = aws_iam_policy.ecs_run.arn
}

resource "aws_iam_policy" "sqs_consume" {
  name = "${var.name}-sqs-consume"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Action = [
        "sqs:ReceiveMessage",
        "sqs:DeleteMessage",
        "sqs:DeleteMessageBatch",
        "sqs:GetQueueAttributes",
        "sqs:GetQueueUrl",
        "sqs:ChangeMessageVisibility",
        "sqs:ChangeMessageVisibilityBatch"
      ],
      Resource = var.queue_arn
    }]
  })
}

resource "aws_iam_role_policy_attachment" "sqs_consume_attach" {
  role       = aws_iam_role.role.name
  policy_arn = aws_iam_policy.sqs_consume.arn
}

resource "aws_lambda_function" "fn" {
  function_name    = var.name
  role             = aws_iam_role.role.arn
  handler          = "handler.lambda_handler"
  runtime          = "python3.11"
  filename         = data.archive_file.zip.output_path
  source_code_hash = data.archive_file.zip.output_base64sha256
  timeout          = 20

  environment {
    variables = {
      CLUSTER_ARN  = var.cluster_arn
      TASK_DEF_ARN = var.task_def_arn
      SUBNET_IDS   = join(",", var.subnet_ids)
      SEC_GROUP_ID = var.security_group
    }
  }

  tags = var.tags
}

resource "aws_lambda_event_source_mapping" "sqs" {
  event_source_arn                   = var.queue_arn
  function_name                      = aws_lambda_function.fn.arn
  batch_size                         = 5
  maximum_batching_window_in_seconds = 1
  function_response_types            = ["ReportBatchItemFailures"]
  scaling_config { maximum_concurrency = 2 }
}


