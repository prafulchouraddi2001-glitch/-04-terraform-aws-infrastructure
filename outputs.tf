output "vpc_id" {
  description = "ID of the Project 4 VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_id" {
  description = "ID of the Project 4 public subnet"
  value       = aws_subnet.public.id
}

output "security_group_id" {
  description = "ID of the Project 4 web security group"
  value       = aws_security_group.web.id
}

output "instance_id" {
  description = "ID of the Project 4 EC2 instance"
  value       = aws_instance.web.id
}

output "instance_private_ip" {
  description = "Private IP address of the Project 4 EC2 instance"
  value       = aws_instance.web.private_ip
}

output "instance_public_ip" {
  description = "Public IP address of the Project 4 EC2 instance"
  value       = aws_instance.web.public_ip
}
