module "key_pair" {
  source  = "terraform-aws-modules/key-pair/aws"
  version = "~> 2.0"

  # key_name_prefix    = local.name
  key_name = var.ec2_key_pair
  create_private_key = true

  tags = local.tags
}

data "aws_ami" "amazon_linux_2" {
  most_recent = true
  filter {
    name   = "owner-alias"
    values = ["amazon"]
  }

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-ebs"]
  }

  owners = ["amazon"]
}


data "http" "ipinfo" {
  url = "http://ipinfo.io/ip"
}

resource "aws_instance" "ec2_bastion_host" {

  depends_on = [
    module.vpc.vpc_id
  ]

  ami                         = data.aws_ami.amazon_linux_2.id
  associate_public_ip_address = true
  instance_type               = "t3.medium"
  key_name                    = module.key_pair.key_pair_name
  vpc_security_group_ids      = ["${aws_security_group.security_group_eks_bastion.id}"]
  subnet_id                   = element(module.vpc.public_subnets, 0)

  user_data = <<-EOF
            #!/bin/bash
            hostnamectl --static set-hostname "AEWS-bastion-host"

            # Config convenience
            echo 'alias vi=vim' >> /etc/profile
            echo "sudo su -" >> /home/ec2-user/.bashrc

            # Change Timezone
            sed -i "s/UTC/Asia\/Seoul/g" /etc/sysconfig/clock
            ln -sf /usr/share/zoneinfo/Asia/Seoul /etc/localtime

            # Install Packages
            cd /root
            yum -y install tree jq git htop lynx amazon-efs-utils

            # Install kubectl & helm
            #curl -O https://s3.us-west-2.amazonaws.com/amazon-eks/1.26.2/2023-03-17/bin/linux/amd64/kubectl
            curl -O https://s3.us-west-2.amazonaws.com/amazon-eks/1.25.7/2023-03-17/bin/linux/amd64/kubectl
            install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
            curl -s https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash
            
            # Install eksctl
            curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
            mv /tmp/eksctl /usr/local/bin

            # Install aws cli v2
            curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
            unzip awscliv2.zip >/dev/null 2>&1
            sudo ./aws/install
            complete -C '/usr/local/bin/aws_completer' aws
            echo 'export AWS_PAGER=""' >>/etc/profile

            # Install YAML Highlighter
            wget https://github.com/andreazorzetto/yh/releases/download/v0.4.0/yh-linux-amd64.zip
            unzip yh-linux-amd64.zip
            mv yh /usr/local/bin/

            # Install krew
            curl -LO https://github.com/kubernetes-sigs/krew/releases/download/v0.4.3/krew-linux_amd64.tar.gz
            tar zxvf krew-linux_amd64.tar.gz
            ./krew-linux_amd64 install krew
            export PATH="$PATH:/root/.krew/bin"
            echo 'export PATH="$PATH:/root/.krew/bin"' >> /etc/profile

            # Install kube-ps1
            echo 'source <(kubectl completion bash)' >> /etc/profile
            echo 'alias k=kubectl' >> /etc/profile
            echo 'complete -F __start_kubectl k' >> /etc/profile

            git clone https://github.com/jonmosco/kube-ps1.git /root/kube-ps1
            cat <<"EOT" >> /root/.bash_profile
            source /root/kube-ps1/kube-ps1.sh
            KUBE_PS1_SYMBOL_ENABLE=false
            function get_cluster_short() {
              echo "$1" | cut -d . -f1
            }
            KUBE_PS1_CLUSTER_FUNCTION=get_cluster_short
            KUBE_PS1_SUFFIX=') '
            PS1='$(kube_ps1)'$PS1
            EOT

            # Install krew plugin
            kubectl krew install ctx ns get-all  # ktop df-pv mtail tree

            # Install Docker
            amazon-linux-extras install docker -y
            systemctl start docker && systemctl enable docker

            # Create SSH Keypair
            ssh-keygen -t rsa -N "" -f /root/.ssh/id_rsa

            # IAM User Credentials
            export AWS_ACCESS_KEY_ID=${var.MyIamUserAccessKeyID}
            export AWS_SECRET_ACCESS_KEY=${var.MyIamUserSecretAccessKey}
            export AWS_DEFAULT_REGION=${local.region}
            export ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' --output text)
            echo "export AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID" >> /etc/profile
            echo "export AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY" >> /etc/profile
            echo "export AWS_REGION=$AWS_DEFAULT_REGION" >> /etc/profile
            echo "export AWS_DEFAULT_REGION=$AWS_DEFAULT_REGION" >> /etc/profile
            echo "export ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' --output text)" >> /etc/profile

            # CLUSTER_NAME
            export CLUSTER_NAME=${var.cluster_name}
            echo "export CLUSTER_NAME=$CLUSTER_NAME" >> /etc/profile

            echo 'cloudinit End!'
            EOF

  user_data_replace_on_change = true

  tags = {
    Name = "ec2_bastion_host"
  }
}


resource "aws_security_group" "security_group_eks_bastion" {
  name        = "security_group_eks_bastion"
  description = "security_group_eks_bastion"
  vpc_id      = module.vpc.vpc_id
  tags = {
    "Name" = "security_group_eks_bastion"
  }
}

resource "aws_security_group_rule" "security_group_rule_eks_bastion_ingress" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["${chomp(data.http.ipinfo.body)}/32"]
  security_group_id = aws_security_group.security_group_eks_bastion.id
}

resource "aws_security_group_rule" "security_group_rule_eks_bastion_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.security_group_eks_bastion.id
}