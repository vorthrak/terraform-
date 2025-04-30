terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "us-east-1"
}

# Create a VPC
resource "aws_vpc" "vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true

  tags = {
    Name = "Terraform-vpc"
  }
}

# Create a internet gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "Terraform-igw"
  }
}

# Create egress
resource "aws_egress_only_internet_gateway" "egress_igw" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "Terraform-egress"
  }
}

# Create public subnet
resource "aws_subnet" "subnet_public_1a" {
  vpc_id     = aws_vpc.vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet-1a"
  }
}

resource "aws_subnet" "subnet_public_1b" {
  vpc_id     = aws_vpc.vpc.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "us-east-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet-1b"
  }
}

# Create private subnet
resource "aws_subnet" "subnet_private_1a" {
  vpc_id     = aws_vpc.vpc.id
  cidr_block = "10.0.3.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "private-subnet-1a"
  }
}

resource "aws_subnet" "subnet_private_1b" {
  vpc_id     = aws_vpc.vpc.id
  cidr_block = "10.0.4.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "private-subnet-1b"
  }
}

# Create route table public
resource "aws_route_table" "rt_public" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "Terraform-rt-public"
  }
}

# Create route table association public
resource "aws_route_table_association" "association_public_1a" {
  subnet_id      = aws_subnet.subnet_public_1a.id
  route_table_id = aws_route_table.rt_public.id
}

resource "aws_route_table_association" "association_public_1b" {
  subnet_id      = aws_subnet.subnet_public_1b.id
  route_table_id = aws_route_table.rt_public.id
}

# Create EIP
resource "aws_eip" "eip" {
  domain = "vpc"
}

# Association eip
resource "aws_eip_association" "eip_association" {
  allocation_id = aws_eip.eip.id
  network_interface_id = aws_network_interface.eni.id
}

# Create network interface
resource "aws_network_interface" "eni" {
  subnet_id       = aws_subnet.subnet_public_1a.id
  security_groups = [aws_security_group.sg_instance.id]
  source_dest_check = false
}

# Create nat instance 
resource "aws_instance" "nat_instance" {
  ami           = "ami-0015c0130d6cc5da7"
  instance_type = "t2.micro"
  key_name = "Terraform-kp" 
  network_interface {
    network_interface_id = aws_network_interface.eni.id
    device_index         = 0
  }

  tags = {
    Name = "Terraform-bastion"
  }
}

# Create route table private
resource "aws_route_table" "rt_private" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "Terraform-rt-private"
  }
}

# Create private route
resource "aws_route" "route_private" {
  route_table_id            = aws_route_table.rt_private.id
  destination_cidr_block    = "0.0.0.0/0"
  network_interface_id = aws_network_interface.eni.id
}

# Create route table association private
resource "aws_route_table_association" "association_private_1a" {
  subnet_id      = aws_subnet.subnet_private_1a.id
  route_table_id = aws_route_table.rt_private.id
}

resource "aws_route_table_association" "association_private_1b" {
  subnet_id      = aws_subnet.subnet_private_1b.id
  route_table_id = aws_route_table.rt_private.id
}

# Create private instance
resource "aws_instance" "instance_1a" {
  instance_type = "t2.micro"
  availability_zone = "us-east-1a"
  key_name = "Terraform-kp"
  ami = "ami-0e449927258d45bc4"
  security_groups = [aws_security_group.sg_instance.id]
  subnet_id = aws_subnet.subnet_private_1a.id
  user_data = <<-EOF
              #!/bin/bash
              sudo yum update -y 
              sudo yum install -y httpd 
              sudo systemctl start httpd
              sudo systemctl enable httpd
              EOF

  tags = {
    Name = "private-1a"
  }
}

resource "aws_instance" "instance_1b" {
  instance_type = "t2.micro"
  ami = "ami-0e449927258d45bc4"
  availability_zone = "us-east-1b"
  key_name = "Terraform-kp"
  security_groups = [aws_security_group.sg_instance.id]
  subnet_id = aws_subnet.subnet_private_1b.id
  user_data = <<-EOF
              #!/bin/bash
              sudo yum update -y 
              sudo yum install -y httpd 
              sudo systemctl start httpd
              sudo systemctl enable httpd
              EOF

  tags = {
    Name = "private-1b"
  }
}

# Create load balancer
resource "aws_lb" "lb" {
  name               = "Terraform-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.sg_instance.id]
  subnets            = [aws_subnet.subnet_public_1a.id, aws_subnet.subnet_public_1b.id]
  ip_address_type = "ipv4"

  tags = {
    Name = "Terraform-lb"
  }
}

# Create target group 
resource "aws_lb_target_group" "tg_alb" {
  name     = "tg-alb"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.vpc.id
  target_type = "instance"
  ip_address_type = "ipv4"
  health_check {
    healthy_threshold = 2
    interval = 30
    path = "/"
    protocol = "HTTP"
    timeout = 5
    unhealthy_threshold = 2
  }
}

# Create listener 
resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.lb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg_alb.arn
  }
}

# attchment target group
resource "aws_lb_target_group_attachment" "tg_attachment_1a" {
  target_group_arn = aws_lb_target_group.tg_alb.arn
  target_id        = aws_instance.instance_1a.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "tg_attachment_1b" {
  target_group_arn = aws_lb_target_group.tg_alb.arn
  target_id        = aws_instance.instance_1b.id
  port             = 80
}

# Create security group 
resource "aws_security_group" "sg_instance" {
  name        = "Terraform-sg-instance"
  description = "Allow all port"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Terraform-sg-instance"
  }
}