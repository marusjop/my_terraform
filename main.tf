#Retrieve the list of AZs in the current AWS region
data "aws_availability_zones" "available" {}
data "aws_region" "current" {}

locals {
  team        = "api_mgmt_dev"
  application = "corp_api"
  server_name = "ec2-${var.environment}-api-${var.variables_sub_az}"
}

#Define the VPC
resource "aws_vpc" "vpc" {
  cidr_block = var.vpc_cidr

  tags = {
    Name        = var.vpc_name
    Environment = "demo_environment"
    Terraform   = "true"
    Region      = data.aws_region.current.name
  }
}

#Deploy the private subnets
resource "aws_subnet" "private_subnets" {
  for_each          = var.private_subnets
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, each.value)
  availability_zone = tolist(data.aws_availability_zones.available.names)[each.value]

  tags = {
    Name      = each.key
    Terraform = "true"
  }
}

#Deploy the public subnets
resource "aws_subnet" "public_subnets" {
  for_each                = var.public_subnets
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, each.value + 100)
  availability_zone       = tolist(data.aws_availability_zones.available.names)[each.value]
  map_public_ip_on_launch = true

  tags = {
    Name      = each.key
    Terraform = "true"
  }
}

#Create route tables for public and private subnets
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet_gateway.id
    #nat_gateway_id = aws_nat_gateway.nat_gateway.id
  }
  tags = {
    Name      = "demo_public_rtb"
    Terraform = "true"
  }
}
resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    # gateway_id = aws_internet_gateway.internet_gateway.id
    nat_gateway_id = aws_nat_gateway.nat_gateway.id
  }
  tags = {
    Name      = "demo_private_rtb"
    Terraform = "true"
  }
}

#Create route table associations

resource "aws_route_table_association" "public" {
  depends_on     = [aws_subnet.public_subnets]
  route_table_id = aws_route_table.public_route_table.id
  for_each       = aws_subnet.public_subnets
  subnet_id      = each.value.id
}

resource "aws_route_table_association" "private" {
  depends_on     = [aws_subnet.private_subnets]
  route_table_id = aws_route_table.private_route_table.id
  for_each       = aws_subnet.private_subnets
  subnet_id      = each.value.id
}

#Create Internet Gateway
resource "aws_internet_gateway" "internet_gateway" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = "demo_igw"
  }
}

#Create EIP for NAT Gateway
resource "aws_eip" "nat_gateway_eip" {
  vpc        = true
  depends_on = [aws_internet_gateway.internet_gateway]

  tags = {
    Name = "demo_igw_eip"
  }
}

#Create NAT Gateway
resource "aws_nat_gateway" "nat_gateway" {
  depends_on    = [aws_subnet.public_subnets]
  allocation_id = aws_eip.nat_gateway_eip.id
  subnet_id     = aws_subnet.public_subnets["public_subnet_1"].id

  tags = {
    Name = "demo_nat_gateway"
  }
}

# Terraform Data Block - To Lookup Latest Ubuntu 20.04 AMI Image
data "aws_ami" "ubuntu" {
  most_recent = true
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  owners = ["099720109477"]
}
# Terraform Resource Block - To Build EC2 instance in Public Subnet
# resource "aws_instance" "web_server" {
#   ami                         = data.aws_ami.ubuntu.id
#   instance_type               = "t3.micro"
#   subnet_id                   = aws_subnet.public_subnets["public_subnet_1"].id
#   security_groups             = [aws_security_group.ingress-ssh.id, aws_security_group.vpc-web.id]
#   associate_public_ip_address = true
#   key_name                    = aws_key_pair.generated.key_name
#   connection {
#     user        = "ubuntu"
#     private_key = tls_private_key.generated.private_key_pem
#     host        = self.public_ip
#   }

#   tags = {
#     Name  = local.server_name
#     Owner = local.team
#     App   = local.application
#     Cos   = data.aws_region.current.name
#   }

#   provisioner "local-exec" {
#     command = "chmod 600 ${local_file.private_key_pem.filename}"
#   }

#   provisioner "remote-exec" {
#     inline = [
#       "sudo rm -rf /tmp",
#       "sudo git clone https://github.com/hashicorp/demo-terraform-101 /tmp",
#       "sudo sh /tmp/assets/setup-web.sh",
#     ]
#   }

#   lifecycle {
#     ignore_changes = [security_groups]
#   }
# }

# resource "aws_instance" "web_server2" {
#   ami                         = data.aws_ami.ubuntu.id
#   instance_type               = "t3.micro"
#   subnet_id                   = aws_subnet.public_subnets["public_subnet_1"].id
#   security_groups             = [aws_security_group.ingress-ssh.id, aws_security_group.vpc-web.id]
#   associate_public_ip_address = true
#   key_name                    = aws_key_pair.generated.key_name
#   connection {
#     user        = "ubuntu"
#     private_key = tls_private_key.generated.private_key_pem
#     host        = self.public_ip
#   }

#   tags = {
#     Name  = "Web server 2"
#     Owner = local.team
#     App   = local.application
#     Cos   = data.aws_region.current.name
#   }

#   provisioner "local-exec" {
#     command = "chmod 600 ${local_file.private_key_pem.filename}"
#   }

#   provisioner "remote-exec" {
#     inline = [
#       "sudo rm -rf /tmp",
#       "sudo git clone https://github.com/hashicorp/demo-terraform-101 /tmp",
#       "sudo sh /tmp/assets/setup-web.sh",
#     ]
#   }

#   lifecycle {
#     ignore_changes = [security_groups]
#   }
# }


# output "public_url" {
#   value = "https://${aws_instance.web_server.private_ip}:8080/index.html"
# }


resource "tls_private_key" "generated" {
  algorithm = "RSA"
}
resource "local_file" "private_key_pem" {
  content  = tls_private_key.generated.private_key_pem
  filename = "MyAWSKey.pem"
}

resource "aws_key_pair" "generated" {
  key_name   = "MyAWSKey"
  public_key = tls_private_key.generated.public_key_openssh
  lifecycle {
    ignore_changes = [key_name]
  }
}

# Security Groups
resource "aws_security_group" "ingress-ssh" {
  name   = "allow-all-ssh"
  vpc_id = aws_vpc.vpc.id
  ingress {
    cidr_blocks = [
      "0.0.0.0/0"
    ]
    from_port = 22
    to_port   = 22
    protocol  = "tcp"
  }
  // Terraform removes the default rule
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Create Security Group - Web Traffic
resource "aws_security_group" "vpc-web" {
  name        = "vpc-web-${terraform.workspace}"
  vpc_id      = aws_vpc.vpc.id
  description = "Web Traffic"
  ingress {
    description = "Allow Port 80"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "Allow Port 443"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    description = "Allow all ip and ports outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

module "server" {
  source                 = "./modules/server"
  ami                    = data.aws_ami.ubuntu.id
  subnet_id              = aws_subnet.public_subnets["public_subnet_1"].id
  vpc_security_group_ids = [aws_security_group.ingress-ssh.id, aws_security_group.vpc-web.id]
}

# module "server_subnet_3" {
#   source          = "./modules/web_server"
#   ami             = data.aws_ami.ubuntu.id
#   subnet_id       = aws_subnet.public_subnets["public_subnet_3"].id
#   security_groups = [aws_security_group.ingress-ssh.id, aws_security_group.vpc-web.id]
#   key_name        = aws_key_pair.generated.key_name
#   private_key     = tls_private_key.generated.private_key_pem
#   user            = "ubuntu"
# }

# module "autoscaling" {
#   source  = "terraform-aws-modules/autoscaling/aws"
#   version = "4.9.0"
#   # Autoscaling group
#   name                = "myasg"
#   vpc_zone_identifier = [aws_subnet.private_subnets["private_subnet_1"].id, aws_subnet.private_subnets["private_subnet_2"].id, aws_subnet.private_subnets["private_subnet_3"].id]
#   min_size            = 0
#   max_size            = 1
#   desired_capacity    = 1
#   # Launch template
#   use_lt        = true
#   create_lt     = true
#   image_id      = data.aws_ami.ubuntu.id
#   instance_type = "t3.micro"
#   # tags = {
#   #   Name = "Web EC2 Server 2"
#   # }
# }

# output "AWS_group_size" {
#   value = module.autoscaling.autoscaling_group_max_size
# }

module "s3-bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "2.11.1"
}

output "s3_bucket_name" {
  value = module.s3-bucket.s3_bucket_bucket_domain_name
}

module "vpc" {
  source             = "terraform-aws-modules/vpc/aws"
  version            = "5.1.1"
  name               = "my-vpc-terraform"
  cidr               = "10.0.0.0/16"
  azs                = ["eu-north-1a", "eu-north-1b", "eu-north-1c"]
  private_subnets    = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets     = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
  enable_nat_gateway = true
  enable_vpn_gateway = true
  tags = {
    Name        = "VPC from Module"
    Terraform   = "true"
    Environment = "dev"
  }
}




# resource "aws_s3_bucket" "my-new-S3-bucket" {
#   bucket = "my-new-tf-test-bucket-${random_password.randomness.id}"
#   acl    = "private"
#   tags = {
#     Name    = "My S3 Bucket"
#     Purpose = "Intro to Resource Blocks Lab"
#   }
# }

# resource "aws_security_group" "my-new-security-group" {
#   name        = "web_server_inbound"
#   description = "Allow inbound traffic on tcp/443"
#   vpc_id      = aws_vpc.vpc.id
#   ingress {
#     description = "Allow 443 from the Internet"
#     from_port   = 443
#     to_port     = 443
#     protocol    = "tcp"
#     cidr_blocks = ["0.0.0.0/0"]
#   }
#   tags = {
#     Name    = "web_server_inbound"
#     Purpose = "Intro to Resource Blocks Lab"
#   }
# }

# resource "random_password" "randomness" {
#   length  = 4
#   upper   = false
#   special = false
# }

# resource "aws_subnet" "variables-subnet" {
#   vpc_id                  = aws_vpc.vpc.id
#   cidr_block              = var.variables_sub_cidr
#   availability_zone       = var.variables_sub_az
#   map_public_ip_on_launch = var.variables_sub_auto_ip
#   tags = {
#     Name      = "sub-variables-${var.variables_sub_az}"
#     Terraform = "true"
#   }
# }
