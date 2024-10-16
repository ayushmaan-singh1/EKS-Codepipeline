# Configuring the AWS Provider
provider "aws" {
  version = "~> 5.70.0"
  region  = "ap-south-1"
}

# Creating VPC
resource "aws_vpc" "my-vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "my-vpc"
  }
}

# Creating Public Subnet
resource "aws_subnet" "Public1" {
  vpc_id                  = aws_vpc.my-vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "ap-south-1a"
  tags = {
    Name = "Public_subnet2"
  }
}

resource "aws_subnet" "Public2" {
  vpc_id                  = aws_vpc.my-vpc.id
  cidr_block              = "10.0.3.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "ap-south-1c"
  tags = {
    Name = "Public_subnet2"
  }
}


# Creating Private Subnet
resource "aws_subnet" "Private" {
  vpc_id            = aws_vpc.my-vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "ap-south-1b"
  tags = {
    Name = "Private_subnet"
  }
}

# Creating Internet Gateway
resource "aws_internet_gateway" "my-igw" {
  vpc_id = aws_vpc.my-vpc.id
  tags = {
    Name = "my-igw"
  }
}

# Public Route Table
resource "aws_route_table" "Public_RT" {
  vpc_id = aws_vpc.my-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.my-igw.id
  }

  tags = {
    Name = "Public_RT"
  }
}

# Associating Public Subnet RT
resource "aws_route_table_association" "public1_subnet_assoc" {
  subnet_id      = aws_subnet.Public1.id
  route_table_id = aws_route_table.Public_RT.id
}

resource "aws_route_table_association" "public2_subnet_assoc" {
  subnet_id      = aws_subnet.Public2.id
  route_table_id = aws_route_table.Public_RT.id
}

# Creating Security Group to Allow SSH and All Traffic
resource "aws_security_group" "my-SG" {
  description = "Allowing all traffic for EKS"
  vpc_id      = aws_vpc.my-vpc.id
  # Allow all other traffic
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "my-SG"
  }
}


# EKS Cluster
resource "aws_eks_cluster" "Ayushmaan-EKS" {
  name     = "Ayushmaan-EKS"
  role_arn = "arn:aws:iam::851725241695:role/Ayushmaan-EKS" 

  vpc_config {
    subnet_ids             = [aws_subnet.Public1.id, aws_subnet.Public2.id]
    security_group_ids     = [aws_security_group.my-SG.id]
    endpoint_public_access = true
    endpoint_private_access = false
  }

  tags = {
    Name = "Ayushmaan-EKS"
  }
}

# Data source for EKS addon versions
data "aws_eks_addon_version" "vpc_cni" {
  addon_name         = "vpc-cni"
  kubernetes_version = aws_eks_cluster.Ayushmaan-EKS.version
  most_recent        = true
}

data "aws_eks_addon_version" "kube_proxy" {
  addon_name         = "kube-proxy"
  kubernetes_version = aws_eks_cluster.Ayushmaan-EKS.version
  most_recent        = true
}


# EKS Addon for VPC CNI
resource "aws_eks_addon" "vpc_cni" {
  cluster_name  = aws_eks_cluster.Ayushmaan-EKS.name
  addon_name    = "vpc-cni"
  addon_version = data.aws_eks_addon_version.vpc_cni.version
}



# EKS Addon for Kube Proxy
resource "aws_eks_addon" "kube_proxy" {
  cluster_name  = aws_eks_cluster.Ayushmaan-EKS.name
  addon_name    = "kube-proxy"
  addon_version = data.aws_eks_addon_version.kube_proxy.version
}

# EKS Node Group 
resource "aws_eks_node_group" "Ayushmaan-NG" {
  cluster_name    = aws_eks_cluster.Ayushmaan-EKS.name
  node_role_arn   = "arn:aws:iam::851725241695:role/EKSFull"  
  subnet_ids      = [aws_subnet.Public1.id, aws_subnet.Public2.id]

  scaling_config {
    desired_size = 1
    max_size     = 1
    min_size     = 1
  }
  ami_type = "AL2_x86_64"
  instance_types = ["t2.medium"]
  capacity_type = "ON_DEMAND"
  disk_size = 20
  
  remote_access {
  ec2_ssh_key = "server"
  source_security_group_ids = [aws_security_group.my-SG.id]
  }
  tags = {
    Name = "EKS-Node-Group"
  }
}

# AWS Instance
resource "aws_instance" "operating" {
  ami                 = "ami-0dee22c13ea7a9a67"
  instance_type       = "t2.medium"
  key_name            = "server" 
  subnet_id           = aws_subnet.Public1.id
  vpc_security_group_ids = [aws_security_group.my-SG.id]

  iam_instance_profile = "EC2-EKS"  

  # User Data
  user_data = <<-EOF
	      #!/bin/bash
	      sudo apt -y update
	      sudo apt -y install docker.io openjdk-21* unzip
	      # AWS CLI installation
	      curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
	      unzip awscliv2.zip
	      sudo ./aws/install
	      # EKSCTL installation
	      ARCH=amd64
	      PLATFORM=$(uname -s)_$ARCH
	      curl -sLO "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_$PLATFORM.tar.gz"
	      tar -xzf eksctl_$PLATFORM.tar.gz -C /tmp && rm eksctl_$PLATFORM.tar.gz
	      sudo mv /tmp/eksctl /usr/local/bin
	      # KUBECTL installation
	      curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
	      sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
              aws configure set aws_access_key_id $AWS_ACCESS_KEY_ID
              aws configure set aws_secret_access_key $AWS_SECRET_ACCESS_KEY
              aws configure set default.region ap-south-1
              echo "$DOCKERHUB_PASSWORD" | sudo dockerhub login -u $DOCKERHUB_USERNAME --passsword-stdin
              aws eks update-kubeconfig --name Ayushmaan-EKS --region ap-south-1
              EOF
  
  tags = {
    Name = "operating"
  }
}
