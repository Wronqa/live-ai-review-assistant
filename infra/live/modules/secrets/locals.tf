locals {
  tags = merge(var.tags, { ManagedBy = "terraform" })
}