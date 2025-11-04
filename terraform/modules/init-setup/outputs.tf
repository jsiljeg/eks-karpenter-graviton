output "vpc_id" { value = aws_vpc.this.id }
output "private_subnets" { value = [for s in aws_subnet.private : s.id] }
output "public_subnets" { value = [for s in aws_subnet.public : s.id] }
output "node_security_group_id" { value = aws_security_group.node.id }
output "private_route_table_ids"{ value = [aws_route_table.private.id] } # single RT, 1 NAT

