output "vpc_id"            { value = aws_vpc.this.id }
output "public_subnet_ids" { value = [for s in aws_subnet.public : s.id] }
output "ecs_sg_id"         { value = aws_security_group.ecs_tasks.id }