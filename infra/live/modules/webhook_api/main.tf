data "archive_file" "zip" {
  type        = "zip"
  source_dir  = var.lambda_source_dir
  output_path = "${path.module}/.tmp/${var.name}.zip"
}

resource "aws_iam_role" "lambda_role" {
  name               = "${var.name}-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17", Statement = [{
      Effect = "Allow", Principal = { Service = "lambda.amazonaws.com" }, Action = "sts:AssumeRole"
    }]
  })
  tags = var.tags
}

resource "aws_iam_policy" "lambda_basic_logs" {
  name   = "${var.name}-basic-logs"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Action = ["logs:CreateLogGroup","logs:CreateLogStream","logs:PutLogEvents"],
      Resource = "*"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "attach_logs" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_basic_logs.arn
}

resource "aws_lambda_function" "fn" {
  function_name    = var.name
  role             = aws_iam_role.lambda_role.arn
  handler          = "handler.lambda_handler"
  runtime          = "python3.11"
  filename         = data.archive_file.zip.output_path
  source_code_hash = data.archive_file.zip.output_base64sha256
  memory_size      = var.memory_size
  timeout          = var.timeout
  environment {
    variables = {
      APP_ENV = var.env
      WEBHOOK_SECRET_ID= var.webhook_secret_id
      GITHUB_TOKEN_ID  = var.github_token_id
      PR_EVENTS_SQS_URL= var.sqs_queue_url
    }
  }
  tags = var.tags
}

resource "aws_apigatewayv2_api" "http" {
  name          = "${var.name}-httpapi"
  protocol_type = "HTTP"
  tags          = var.tags
}

resource "aws_apigatewayv2_integration" "int" {
  api_id                 = aws_apigatewayv2_api.http.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.fn.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "route" {
  api_id    = aws_apigatewayv2_api.http.id
  route_key = "POST /webhook"
  target    = "integrations/${aws_apigatewayv2_integration.int.id}"
}

resource "aws_apigatewayv2_stage" "stage" {
  api_id      = aws_apigatewayv2_api.http.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_lambda_permission" "allow_apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.fn.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http.execution_arn}/*/*"
}

data "aws_secretsmanager_secret" "webhook" { 
  arn = var.webhook_secret_id 
}

data "aws_secretsmanager_secret" "token"   { 
  arn = var.github_token_id   
}

resource "aws_iam_policy" "lambda_secrets_read" {
  name   = "${var.name}-secrets-read"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect   = "Allow",
      Action   = ["secretsmanager:GetSecretValue"],
      Resource = [
        data.aws_secretsmanager_secret.webhook.arn,
        data.aws_secretsmanager_secret.token.arn
      ]
    }]
  })
}

resource "aws_iam_policy" "lambda_sqs_send" {
  name   = "${var.name}-sqs-send"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect   = "Allow",
      Action   = ["sqs:SendMessage"],
      Resource = [ var.sqs_queue_arn ]
    }]
  })
}

resource "aws_iam_role_policy_attachment" "attach_secrets_read" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_secrets_read.arn
}

resource "aws_iam_role_policy_attachment" "attach_sqs_send" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_sqs_send.arn
}
