locals {
  name = "${var.name_prefix}-${random_id.suffix.hex}"
  tags = merge(
    var.tags,
    { ManagedBy = "terraform" } 
  )
}