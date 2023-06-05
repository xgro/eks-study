variable "create_eks" {
  default = "true"
}

variable "cluster_name" {
  default = "eks_cluster"
}

variable "cluster_node_group_name" {
  default = "nodegroup1"
}

variable "cluster_version" {
  default = "1.24"
}

variable "ec2_key_pair" {
  default = "aews"
}

