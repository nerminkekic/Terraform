# Deploy VPC resource

resource "aws_vpc" "main" {
  cidr_block           = "10.123.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "dev"
  }
}

# Add subnet

resource "aws_subnet" "main_public_subnet" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.123.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1a"

  tags = {
    Name = "dev-public"
  }
}

# Deploy VPC Internet Gateway

resource "aws_internet_gateway" "main_gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "main_gw"
  }
}

# Deploy Route Touble

resource "aws_route_table" "main_route_table" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "dev_route_table"
  }
}

# Deploy Route

resource "aws_route" "default-route" {
  route_table_id         = aws_route_table.main_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main_gw.id

}

# Associate subnet with route table

resource "aws_route_table_association" "main_public_assoc" {
  subnet_id      = aws_subnet.main_public_subnet.id
  route_table_id = aws_route_table.main_route_table.id
}

# Deploy Security Group

resource "aws_security_group" "main_sg" {
  name        = "allow_ssh_con"
  description = "Allow inbound SSH connection to App server"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.10.10.10/32"]

  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]

  }


}

# Setup EC2 Image parameters 

data "aws_ami" "server_ami" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

}

# Set up Pair key for access to EC2 instance 

resource "aws_key_pair" "main_key" {
  key_name   = "mainkey"
  public_key = file("~/.ssh/mainkey.pub")
}


# Deploy EC2 instance

resource "aws_instance" "dev_ubuntu" {
  ami                    = data.aws_ami.server_ami.id
  instance_type          = "t2.micro"
  key_name               = aws_key_pair.main_key.id
  vpc_security_group_ids = [aws_security_group.main_sg.id]
  subnet_id              = aws_subnet.main_public_subnet.id
  user_data              = file("userdata.tpl")

  root_block_device {
    volume_size = 10
  }

  tags = {
    Name = "dev-node"
  }

}
