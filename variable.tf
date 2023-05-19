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

variable "worker_node_instance_type" {
  default = ["t3.medium"]
}

variable "ebs_csi_driver" {
  type = bool
  default = "false"
}

variable "ebs_csi_drivce_sc_gp3" {
  type = bool
  default = "false"
}

variable "efs_csi_driver" {
  type = bool
  default = "false"
}
