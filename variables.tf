variable "aws_region" {
  description = "AWS region where Project 4 resources will be created"
  type        = string
  default     = "ap-south-1"
}

variable "instance_type" {
  description = "EC2 instance type for the Project 4 web server"
  type        = string
  default     = "t3.micro"
}

variable "vpc_cidr" {
  description = "CIDR block for the Project 4 VPC"
  type        = string
  default     = "10.10.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for the Project 4 public subnet"
  type        = string
  default     = "10.10.1.0/24"
}

variable "availability_zone" {
  description = "Availability Zone for the Project 4 public subnet"
  type        = string
  default     = "ap-south-1b"
}

variable "ssh_allowed_cidr" {
  description = "CIDR block allowed to access EC2 over SSH"
  type        = string
  default     = "116.74.252.161/32"
}
variable "ami_id" {
  description = "AMI ID for the EC2 instance"
  type        = string
}
