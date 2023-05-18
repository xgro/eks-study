locals {
  name   = "myeks-vpc"
  cluster_version = "1.24"
  region = "ap-northeast-2"

  vpc_cidr = "192.168.0.0/16"
  azs      = slice(data.aws_availability_zones.available.names, 0, 2)

  tags = {
    # "kubernetes.io/cluster/${var.eks_cluster_name}" = "shared"
  }
}
