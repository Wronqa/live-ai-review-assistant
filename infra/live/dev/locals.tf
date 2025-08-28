locals {
  project     = var.project
  env         = var.env
  name_prefix = "${local.project}-${local.env}" 
  tags = {
    Project     = local.project
    Environment = local.env
  }
}