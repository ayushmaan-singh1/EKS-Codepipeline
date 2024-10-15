# Configure the AWS Provider
provider "aws" {
  version = "~> 5.0"
  region  = "ap-south-1"
}

# Create a VPC
resource "aws_vpc" "my-vpc" {
  cidr_block = "10.0.0.0/16"
}

#Creating Subnet
resource "aws_subnet" "Public" {
  vpc_id = aws_vpc.my-vpc.id
  cidr_block = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone = "ap-south-1a"
 }

resource "aws_subnet" "Private" {
  vpc_id = aws_vpc.my-vpc.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "ap-south-1b"  
}


#Creating Internet Gateway
  
resource "aws_internet_gateway" "my-igw" {
  vpc_id = aws_vpc.my-vpc.id
}

#Public Route-Table
resource "aws_route_table" "Public_RT" {
  vpc_id = aws_vpc.my-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.my-igw.id
  }
}

#Associating Public subnet with Public_RT
resource "aws_route_table_association" "public_subnet_assoc" {
  subnet_id = aws_subnet.Public.id
  route_table_id = aws_route_table.Public_RT.id
}

#Creating SG
resource "aws_security_group" "my-SG" {
  description = "Allowing ALL"
  vpc_id      = aws_vpc.my-vpc.id
  
  ingress {
	from_port = 0
	to_port   = 0
	protocol  = "-1"
        cidr_blocks = ["0.0.0.0/0"]
   }
  egress {
        from_port = 0
        to_port   = 0
        protocol  = "-1"
        cidr_blocks = ["0.0.0.0/0"]
  }
}
#EKS Cluster Creation
resource "aws_eks_cluster" "Ayushmaan-EKS" {
  name = "Ayushmaan-EKS"
  role_arn = "arn:aws:iam::851725241695:role/Ayushmaan-EKS"

  vpc_config {
    subnet_ids = [aws_subnet.Public.id, aws_subnet.Private.id]
    security_group_ids = [aws_security_group.my-SG.id]
  }
}
#EKS_Node_Group
resource "aws_eks_node_group" "Ayushmaan-NG" {
  cluster_name    = aws_eks_cluster.Ayushmaan-EKS.name
  node_role_arn   = "arn:aws:iam::851725241695:role/EC2-EKS"
  subnet_ids      = [aws_subnet.Public.id]

  scaling_config {
    desired_size = 1
    max_size     = 1
    min_size     = 1
  }
  
  instance_types = ["t2.medium"]
}

#AWS_Instance
resource "aws_instance" "operating" {
  ami           = "ami-0dee22c13ea7a9a67"
  instance_type = "t2.medium"
  key_name      = "server"
  security_groups = [aws_security_group.my-SG.name]
  iam_instance_profile = "arn:aws:iam::851725241695:instance-profile/EKSFull"

  #USER-Data
  user_data = <<-EOF
	      #!/bin/bash
      	      sudo apt -y update
              sudo apt -y install docker.io openjdk-21* unzip
              #AWSCLI
              curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
              unzip awscliv2.zip
              sudo ./aws/install
              # for ARM systems, set ARCH to: `arm64`, `armv6` or `armv7`
              ARCH=amd64
              PLATFORM=$(uname -s)_$ARCH
	      #EKSCTL
              curl -sLO "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_$PLATFORM.tar.gz"

              # (Optional) Verify checksum
              curl -sL "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_checksums.txt" | grep $PLATFORM | sha256sum --check

              tar -xzf eksctl_$PLATFORM.tar.gz -C /tmp && rm eksctl_$PLATFORM.tar.gz

              sudo mv /tmp/eksctl /usr/local/bin
              #KUBECTL
              curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
              sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
              chmod +x kubectl
              mkdir -p ~/.local/bin
              mv ./kubectl ~/.local/bin/kubectl
              EOF
}

