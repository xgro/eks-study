# module "eks" {
#   source = "terraform-aws-modules/eks/aws"

#   cluster_name                          = var.cluster_name
#   cluster_version                       = var.cluster_version
#   cluster_endpoint_private_access       = true
#   cluster_endpoint_public_access        = true
#   cluster_additional_security_group_ids = [aws_security_group.security_group_eks_cluster.id]

#   vpc_id     = module.vpc.vpc_id
#   subnet_ids = module.vpc.private_subnets

#   eks_managed_node_groups = {
#     # Default node group - as provided by AWS EKS
#     "${var.cluster_node_group_name}" = {
#       # disk_size = 50
#       desired_size   = 2
#       min_size       = 2
#       max_size       = 5
#       instance_types = ["t3.medium"]
#       capacity_type  = "SPOT"
#     }
#   }

# }



# module "eks" {
#   source = "terraform-aws-modules/eks/aws"
#   version = "19.10.0"

#   create = var.create_eks

#   cluster_name    = var.cluster_name
#   cluster_version = var.cluster_version

#   cluster_endpoint_private_access = true
#   cluster_endpoint_public_access  = false

#   cluster_additional_security_group_ids = [aws_security_group.security_group_eks_cluster.id]

#   vpc_id     = module.vpc.vpc_id
#   subnet_ids = module.vpc.public_subnets

#   manage_aws_auth_configmap = true

#   eks_managed_node_group_defaults = {
#     ami_type       = "AL2_x86_64"
#     instance_types = ["m6i.large", "m5.large", "m5n.large", "m5zn.large"]

#     # We are using the IRSA created below for permissions
#     # However, we have to deploy with the policy attached FIRST (when creating a fresh cluster)
#     # and then turn this off after the cluster/node group is created. Without this initial policy,
#     # the VPC CNI fails to assign IPs and nodes cannot join the cluster
#     # See https://github.com/aws/containers-roadmap/issues/1666 for more context
#     iam_role_attach_cni_policy = true
#   }

#   eks_managed_node_groups = {
#     # Default node group - as provided by AWS EKS
#     default_node_group = {
#       # By default, the module creates a launch template to ensure tags are propagated to instances, etc.,
#       # so we need to disable it to use the default template provided by the AWS EKS managed node group service
#       use_custom_launch_template = false

#       # disk_size = 50
#       min_size       = 1
#       max_size       = 10
#       desired_size   = 1
#       instance_types = ["t3.large"]
#       capacity_type  = "SPOT"
#     }
#   }

#   attach_cluster_encryption_policy = false

#   cluster_addons = {
#     coredns = {
#       most_recent = true
#     }
#     kube-proxy = {
#       most_recent = true
#     }
#     vpc-cni = {
#       most_recent              = true
#       before_compute           = true
#       service_account_role_arn = module.vpc_cni_irsa.iam_role_arn
#       configuration_values = jsonencode({
#         env = {
#           # Reference docs https://docs.aws.amazon.com/eks/latest/userguide/cni-increase-ip-addresses.html
#           ENABLE_PREFIX_DELEGATION = "true"
#           WARM_PREFIX_TARGET       = "1"
#         }
#       })
#     }
#   }

#   tags = local.tags
# }


# ################################################################################
# # Supporting Resources
# ################################################################################

# module "vpc_cni_irsa" {
#   source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
#   version = "~> 5.0"

#   role_name_prefix      = "VPC-CNI-IRSA"
#   attach_vpc_cni_policy = true
#   vpc_cni_enable_ipv6   = true

#   oidc_providers = {
#     main = {
#       provider_arn               = module.eks.oidc_provider_arn
#       namespace_service_accounts = ["kube-system:aws-node"]
#     }
#   }

#   tags = local.tags
# }

# module "ebs_kms_key" {
#   source  = "terraform-aws-modules/kms/aws"
#   version = "~> 1.5"

#   description = "Customer managed key to encrypt EKS managed node group volumes"

#   # Policy
#   key_administrators = [
#     data.aws_caller_identity.current.arn
#   ]

#   key_service_roles_for_autoscaling = [
#     # required for the ASG to manage encrypted volumes for nodes
#     "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling",
#     # required for the cluster / persistentvolume-controller to create encrypted PVCs
#     module.eks.cluster_iam_role_arn,
#   ]

#   # Aliases
#   aliases = ["eks/${local.name}/ebs"]

#   tags = local.tags
# }

# resource "aws_security_group" "security_group_eks_cluster" {
#   name        = "security_group_eks_cluster"
#   description = "security_group_eks_cluster"
#   vpc_id      = module.vpc.vpc_id
#   tags = {
#     "Name" = "security_group_eks_cluster"
#   }
# }

# resource "aws_security_group_rule" "security_group_rule_eks_cluster_ingress" {
#   type              = "ingress"
#   from_port         = 0
#   to_port           = 65535
#   protocol          = "tcp"
#   cidr_blocks       = ["0.0.0.0/0"]
#   security_group_id = aws_security_group.security_group_eks_cluster.id
# }

# resource "aws_security_group_rule" "security_group_rule_eks_cluster_egress" {
#   type              = "egress"
#   from_port         = 0
#   to_port           = 65535
#   protocol          = "tcp"
#   cidr_blocks       = ["0.0.0.0/0"]
#   security_group_id = aws_security_group.security_group_eks_cluster.id
# }

# resource "aws_security_group" "remote_access" {
#   name_prefix = "${local.name}-remote-access"
#   description = "Allow remote SSH access"
#   vpc_id      = module.vpc.vpc_id

#   ingress {
#     description = "SSH access"
#     from_port   = 22
#     to_port     = 22
#     protocol    = "tcp"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   egress {
#     from_port        = 0
#     to_port          = 0
#     protocol         = "-1"
#     cidr_blocks      = ["0.0.0.0/0"]
#     ipv6_cidr_blocks = ["::/0"]
#   }

#   tags = merge(local.tags, { Name = "${local.name}-remote" })
# }
