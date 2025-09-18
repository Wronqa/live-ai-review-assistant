
locals {
  name                 = var.name
  tags                 = merge(var.tags, { ManagedBy = "terraform" })
}