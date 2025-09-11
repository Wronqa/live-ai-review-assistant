locals {
  table_name = var.table_name
  tags       = merge(var.tags, { ManagedBy = "terraform" })
}