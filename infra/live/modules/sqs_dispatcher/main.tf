resource "aws_cloudwatch_log_group" "lg" {
  name              = "/aws/lambda/${local.name}"
  retention_in_days = var.log_retention_days

  tags = merge(local.tags, { Name = "${local.name}-log-group", Component = "logs" })
}

data "aws_iam_policy_document" "lambda_assume" {
  statement {
    effect = "Allow"
    principals { 
      type = "Service"
      identifiers = ["lambda.amazonaws.com"] 
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "role" {
  name               = "${local.name}-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json

  tags = merge(local.tags, { Name = "${local.name}-role", Component = "iam-role" })
}

resource "aws_iam_role_policy_attachment" "logs" {
  role       = aws_iam_role.role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "aws_iam_policy_document" "sqs_consume" {
  statement {
    effect  = "Allow"
    actions = [
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage",
      "sqs:DeleteMessageBatch",
      "sqs:GetQueueAttributes",
      "sqs:GetQueueUrl",
      "sqs:ChangeMessageVisibility",
      "sqs:ChangeMessageVisibilityBatch"
    ]
    resources = [var.queue_arn]
  }
}

resource "aws_iam_policy" "sqs_consume" {
  name   = "${local.name}-sqs-consume"
  description = "Allow Lambda to consume messages from ${var.queue_arn}"
  policy = data.aws_iam_policy_document.sqs_consume.json

  tags = merge(local.tags, { Name = "${local.name}-sqs-consume", Component = "iam-policy" })
}

data "aws_iam_policy_document" "sqs_produce" {
  statement {
    effect  = "Allow"
    actions = [
      "sqs:SendMessage",
      "sqs:SendMessageBatch"
    ]
    resources = [var.review_queue_arn]
  }
}

resource "aws_iam_policy" "sqs_produce" {
  name   = "${local.name}-sqs-produce"
  description = "Allow Lambda to send messages to ${var.review_queue_arn}"
  policy = data.aws_iam_policy_document.sqs_produce.json

  tags = merge(local.tags, { Name = "${local.name}-sqs-consume", Component = "iam-policy" })
}

data "aws_iam_policy_document" "s3_put" {
  statement {
    effect  = "Allow"
    actions = ["s3:PutObject"]

    resources = ["${var.artifacts_bucket_arn}/*"]

    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-server-side-encryption"
      values   = var.s3_put_sse_algorithm == "aws:kms" ? ["aws:kms"] : ["AES256"]
    }

     dynamic "condition" {
      for_each = var.s3_put_sse_algorithm == "aws:kms" && var.s3_put_kms_key_arn != null ? [1] : []
      content {
        test     = "StringEquals"
        variable = "s3:x-amz-server-side-encryption-aws-kms-key-id"
        values   = [var.s3_put_kms_key_arn]
      }
    }
  }
}

resource "aws_iam_policy" "s3_put" {
  name   = "${local.name}-s3-put"
  description = "Allow Lambda to upload to ${var.artifacts_bucket_arn} with enforced SSE"
  policy = data.aws_iam_policy_document.s3_put.json

  tags = merge(local.tags, { Name = "${local.name}-s3-put", Component = "iam-policy" })
}

data "aws_iam_policy_document" "dynamodb_put" {
  statement {
    effect  = "Allow"
    actions = ["dynamodb:PutItem"]
    resources = [var.idem_table_arn]
  }
}

resource "aws_iam_policy" "dynamodb_put" {
  name   = "${local.name}-dynamodb-put"
  description = "Allow Lambda to write idempotency records into ${var.idem_table_arn}"
  policy = data.aws_iam_policy_document.dynamodb_put.json

  tags = merge(local.tags, { Name = "${local.name}-dynamodb-put", Component = "iam-policy" })
}

resource "aws_iam_role_policy_attachment" "attachments" {
  for_each = {
    sqs_consume = aws_iam_policy.sqs_consume.arn
    sqs_produce = aws_iam_policy.sqs_produce.arn
    s3_put      = aws_iam_policy.s3_put.arn
    ddb_put     = aws_iam_policy.dynamodb_put.arn
  }

  role       = aws_iam_role.role.name
  policy_arn = each.value

   depends_on = [
    aws_iam_role.role,
    aws_iam_policy.sqs_consume,
    aws_iam_policy.sqs_produce,
    aws_iam_policy.s3_put,
    aws_iam_policy.dynamodb_put,
  ]

  lifecycle {
    precondition {
      condition     = each.value != null
      error_message = "Attempted to attach null policy ARN (likely optional ecr_pull disabled)."
    }
  }
}

resource "aws_lambda_function" "fn" {
  function_name    = local.name
  role             = aws_iam_role.role.arn
  package_type     = "Image"
  image_uri        = var.image
  timeout          = var.timeout
  architectures = ["x86_64"]

  environment {
    variables = {
      TARGET_QUEUE_URL       = var.review_queue_url
      ARTIFACTS_BUCKET       = var.artifacts_bucket_name
      IDEMPOTENCY_TABLE      = var.idem_table_name
      GITHUB_TOKEN_SECRET_ARN = var.github_token_arn
      MAX_HUNKS              = 6
      LOG_LEVEL              = "INFO"
    }
  }

  tags = merge(local.tags, { Name = "${local.name}", Component = "lambda" })
}

resource "aws_lambda_event_source_mapping" "sqs" {
  event_source_arn                   = var.queue_arn
  function_name                      = aws_lambda_function.fn.arn
  batch_size                         = var.batch_size
  maximum_batching_window_in_seconds = var.max_batching_window_seconds
  function_response_types            = ["ReportBatchItemFailures"]
  scaling_config { maximum_concurrency = var.max_concurrency }
}




