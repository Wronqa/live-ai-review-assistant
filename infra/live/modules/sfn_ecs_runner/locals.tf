locals {
    name = var.name
    target_sqs_arn = var.send_to_dlq ? var.review_sqs_dlq_arn : var.review_sqs_arn
    target_sqs_url = var.send_to_dlq ? var.review_sqs_dlq_url : var.review_sqs_url
    tags = merge(var.tags, { ManagedBy = "terraform" })
      sfn_definition = jsonencode({
        Comment = "Minimal ECS runner with DLQ on failure"
        StartAt = "RunTask"
        States  = {
          RunTask = {
            Type     = "Task"
            Resource = "arn:aws:states:::ecs:runTask.sync"
            Parameters = {
              Cluster        = var.cluster_arn
              TaskDefinition = var.task_definition_arn
              LaunchType     = "FARGATE"
              NetworkConfiguration = {
                AwsvpcConfiguration = {
                  Subnets        = var.subnet_ids
                  SecurityGroups = var.security_group_ids
                  AssignPublicIp = (var.assign_public_ip ? "ENABLED" : "DISABLED")
                }
              }
              Overrides = {
                ContainerOverrides = [{
                  Name   = var.container_name
                  Cpu    = 1024
                  Memory = 2048
                  Environment = [
                    {
                      Name      = "PAYLOAD"
                      "Value.$" = "$[0].body"
                    }
                  ]
                }]
              }
            }
            Catch = [{
              ErrorEquals = ["States.ALL"]
              Next        = "SendToTarget"
            }]
            End = true
          }
    
          SendToTarget = {
            Type     = "Task"
            Resource = "arn:aws:states:::sqs:sendMessage"
            Parameters = {
              QueueUrl = local.target_sqs_url
              "MessageBody.$" = "$"    
            }
            End = true
          }
        }
      })
}