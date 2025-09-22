data "aws_region" "current" {}

resource "aws_ecs_cluster" "this" {
  name = local.cluster_name

  setting {
    name  = "containerInsights"
    value = var.enable_container_insights ? "enabled" : "disabled"
  }

  tags = merge(local.tags, { Name = "${var.name}-cluster-name",  Component = "ecs-cluster" }) 
}

resource "aws_ecs_cluster_capacity_providers" "this" {
  cluster_name       = aws_ecs_cluster.this.name

   capacity_providers = var.use_fargate_spot ? ["FARGATE", "FARGATE_SPOT"] : ["FARGATE"]

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 1
    base              = 1
  }
}

resource "aws_cloudwatch_log_group" "lg" {
  name              = local.log_group_name
  retention_in_days = 7
  
  tags = merge(local.tags, { Name = "${var.name}-log-group",  Component = "logs" }) 
}

data "aws_iam_policy_document" "exec_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
       type = "Service" 
       identifiers = ["ecs-tasks.amazonaws.com"] 
    }
  }
}

resource "aws_iam_role" "execution_role" {
  name               = "${local.name}-exec-role"
  assume_role_policy = data.aws_iam_policy_document.exec_assume.json

  tags = merge(local.tags, { Name = "${var.name}-exec-role",  Component = "iam-exec-role" }) 
}

resource "aws_iam_role_policy_attachment" "exec_attach" {
  role       = aws_iam_role.execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "task_role" {
  name = local.task_role_name
  assume_role_policy = aws_iam_role.execution_role.assume_role_policy

  tags = merge(local.tags, { Name = "${var.name}-task-role",  Component = "task-role" }) 
}

data "aws_iam_policy_document" "task_s3" {
  statement {
    sid    = "AllowReadArtifacts"
    effect = "Allow"
    actions = [
      "s3:GetObject"
    ]
    resources = [
      "${var.artifact_bucket_arn}/*"  
    ]
  }

  statement {
    sid    = "AllowReadAdapters"
    effect = "Allow"
    actions = ["s3:ListBucket", "s3:GetObject"]
    resources = [
      var.model_adapters_s3_arn,
      "${var.model_adapters_s3_arn}/*"
    ]
  }
}

resource "aws_iam_role_policy" "task_s3" {
  name   = local.task_s3_policy_name
  role   = aws_iam_role.task_role.id
  policy = data.aws_iam_policy_document.task_s3.json
}

data "aws_iam_policy_document" "task_sqs" {
  statement {
    sid     = "AllowRequeue"
    effect  = "Allow"
    actions = ["sqs:ChangeMessageVisibility"]
    resources = [var.review_queue_arn]
  }
}

resource "aws_iam_role_policy" "task_sqs" {
  name   = local.task_sqs_policy_name
  role   = aws_iam_role.task_role.id
  policy = data.aws_iam_policy_document.task_sqs.json
}

resource "aws_ecs_task_definition" "td" {
  family                   = local.task_family
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.cpu
  memory                   = var.memory
  ephemeral_storage { size_in_gib = 60 }
  execution_role_arn       = aws_iam_role.execution_role.arn
  task_role_arn            = aws_iam_role.task_role.arn
  runtime_platform { operating_system_family = "LINUX" }

  container_definitions = jsonencode([
    {
      name      = "worker",
      image     = var.image,
      essential = true,
      environment = concat(
        [
          {"name":"LOG_LEVEL","value":"INFO"},
          {"name":"MAX_BODY_CHARS","value":"250"},
          {"name":"IDEMPOTENCY","value":"true"},
          {"name":"MARKER_PREFIX","value":"lara"},

          {"name":"MODEL_ID","value":"Salesforce/codegen-350M-multi"},
          {"name":"MODEL_DIR","value":"/models"},
          {"name":"GEN_MAX_NEW_TOKENS","value":"80"},
          {"name":"GEN_TEMP","value":"0.2"},
          {"name":"GEN_TOP_P","value":"0.9"},
          {"name":"GEN_TOP_K","value":"50"},
          {"name":"TRUNCATE_HUNK_CHARS","value":"600"},
          {"name":"LORA_ADAPTER_DIR","value":"/models/adapters/codegen350m_lora"},
          {"name":"ADAPTER_BUCKET","value":"codegen-350m-finetune-adapters"},
          {"name":"HF_HUB_CACHE","value":"/models/.cache/huggingface"},

          {"name":"TOKENIZERS_PARALLELISM","value":"false"},
          {"name":"OMP_NUM_THREADS","value":"1"},
          {"name":"MKL_NUM_THREADS","value":"1"},
          {"name":"NUMEXPR_NUM_THREADS","value":"1"},
          {"name":"HF_HUB_ENABLE_HF_TRANSFER","value":"0"},

          { name = "SQS_QUEUE_URL", value = var.review_queue_url },
          { name = "SQS_RECEIPT_HANDLE", value = "" }
        ],
        [
          for k, v in var.env : { name = k, value = v }
        ]
      ),
      logConfiguration = {
        logDriver = "awslogs",
        options = {
          awslogs-group         = aws_cloudwatch_log_group.lg.name,
          awslogs-region        = data.aws_region.current.name,
          awslogs-stream-prefix = "ecs"
        }
      }
    }

  ])

  tags = merge(local.tags, { Name = "${var.name}-task-definition",  Component = "ecs-taskdef" }) 
}