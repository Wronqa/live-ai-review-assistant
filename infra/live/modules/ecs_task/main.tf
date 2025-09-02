data "aws_region" "current" {}

resource "aws_ecs_cluster" "this" {
  name = "${var.name}-cluster"
  setting { 
    name = "containerInsights"
    value = "enabled" 
  }
  tags = var.tags
}

resource "aws_cloudwatch_log_group" "lg" {
  name              = "/ecs/${var.name}"
  retention_in_days = 7
  tags = var.tags
}

resource "aws_iam_role" "execution_role" {
  name = "${var.name}-exec-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{ Effect="Allow", Principal={ Service="ecs-tasks.amazonaws.com" }, Action="sts:AssumeRole" }]
  })
  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "exec_attach" {
  role       = aws_iam_role.execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "task_role" {
  name = "${var.name}-task-role"
  assume_role_policy = aws_iam_role.execution_role.assume_role_policy
  tags = var.tags
}

resource "aws_ecs_task_definition" "td" {
  family                   = "${var.name}-td"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.cpu
  memory                   = var.memory
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
          { name = "APP_ENV",   value = "dev" },
          { name = "LOG_LEVEL", value = "WARNING" }
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
}