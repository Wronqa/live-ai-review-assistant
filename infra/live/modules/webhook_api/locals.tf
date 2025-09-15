locals {
  name = var.name
  tags = merge(var.tags, { ManagedBy = "terraform" })
  zip_name        = "${local.name}.zip"
  zip_output_path = "${path.module}/.tmp/${local.zip_name}"
}
