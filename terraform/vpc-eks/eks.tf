# https://github.com/terraform-aws-modules/terraform-aws-eks
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 18.0"

  cluster_name    = var.project_name # "${var.project_name}-${var.project_env}"
  cluster_version = "1.22"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # cluster_endpoint_private_access = true
  # cluster_endpoint_public_access  = true

  eks_managed_node_group_defaults = {
    disk_size      = 8
    instance_types = ["t2.medium"]
  }

  # Add IAM user ARNs to aws-auth configmap to be able to manage EKS from the AWS website

  # https://github.com/terraform-aws-modules/terraform-aws-eks/blob/master/README.md#input_create_aws_auth_configmap
  # create_aws_auth_configmap = true

  # /!\ https://github.com/terraform-aws-modules/terraform-aws-eks/issues/911#issuecomment-640702294
  # https://github.com/terraform-aws-modules/terraform-aws-eks/blob/master/README.md#input_manage_aws_auth_configmap
  manage_aws_auth_configmap = true

  # https://github.com/terraform-aws-modules/terraform-aws-eks/blob/master/README.md#input_aws_auth_users
  aws_auth_users = [
    {
      "userarn" : "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root",
      "groups" : ["system:masters"]
    }
  ]

  # https://github.com/terraform-aws-modules/terraform-aws-eks/blob/master/README.md#input_aws_auth_accounts
  aws_auth_accounts = [
    data.aws_caller_identity.current.account_id
  ]


  eks_managed_node_groups = {
    green = {
      min_size     = 1
      max_size     = 2
      desired_size = 1

      instance_types = ["t2.medium"]
      capacity_type  = "ON_DEMAND" # SPOT
    }
  }

  node_security_group_additional_rules = {
    ingress_self_all = {
      description = "Node to node all ports/protocols"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "ingress"
      self        = true
    }

    egress_all = {
      description = "Node all egress"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "egress"
      cidr_blocks = ["0.0.0.0/0"]
      # ipv6_cidr_blocks = ["::/0"]
    }
  }

}

# https://github.com/terraform-aws-modules/terraform-aws-eks/blob/master/README.md#output_cluster_id
resource "null_resource" "update_kubeconfig" {
  provisioner "local-exec" {
    command = "aws eks update-kubeconfig --name ${module.eks.cluster_id} --region ${var.region}"
  }

  depends_on = [module.eks]
}

# https://github.com/terraform-aws-modules/terraform-aws-eks/blob/master/README.md#output_cluster_arn
resource "null_resource" "kubectl_rename_context" {

  provisioner "local-exec" {
    command = "kubectl config rename-context ${module.eks.cluster_arn} ${var.project_name}"
  }

  depends_on = [null_resource.update_kubeconfig]
}

/* 
  /!\ Important

  Uncomment the module + 2 resources below to create
  1. create IAM Role with Federated Trust Relationship `"Action": "sts:AssumeRoleWithWebIdentity"`
  2. attach the policy previously created with in dynamo-ecr/iam.tf `resource "aws_iam_policy" "policy"`
     which allows "dynamodb:GetItem" + "dynamodb:UpdateItem"
  3. create a kubernetes service account linked with the IAM Role created at 1)
     linked by annotations + namespace:name <-> namespace_service_accounts
*/

/**/
# https://github.com/terraform-aws-modules/terraform-aws-iam/tree/master/modules/iam-role-for-service-accounts-eks
module "iam_eks_role" {
  source    = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  role_name = "${var.project_name}-service-account-role"

  oidc_providers = {
    one = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["vote:eks-dynamo"]
    }
  }
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment
resource "aws_iam_role_policy_attachment" "policy_attachment" {
  role       = module.iam_eks_role.iam_role_name
  policy_arn = data.aws_iam_policy.policy.arn
}

# https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/service_account
resource "kubernetes_service_account" "service_account" {
  metadata {
    name      = "eks-dynamo"
    namespace = "vote"

    annotations = {
      "eks.amazonaws.com/role-arn" = module.iam_eks_role.iam_role_arn
    }
  }
}
