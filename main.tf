provider "aws" {
  region = local.region
}

terraform {
  backend "s3" {
    bucket = "awseksbucket123"
    key    = "prod/terraform.tfstate"
    region = "us-east-1"
  }
}

provider "aws" {
  region = "us-east-1"
  alias  = "virginia"
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      # This requires the awscli to be installed locally where Terraform is executed
      args = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
    }
  }
}

provider "kubectl" {
  apply_retry_count      = 5
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  load_config_file       = false

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    # This requires the awscli to be installed locally where Terraform is executed
    args = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
  }
}

data "aws_availability_zones" "available" {}
data "aws_ecrpublic_authorization_token" "token" {
  provider = aws.virginia
}


locals {
  name            = "hss_infra"
  cluster_version = "1.29"
  region          = "eu-west-1"

  vpc_cidr = "10.0.0.0/16"
  azs = slice(data.aws_availability_zones.available.names, 0, min(length(data.aws_availability_zones.available.names), 3))

  tags = {
    cluster_name    = local.name
    GithubRepo = "hhs_eks_infra_optimised"
    GithubOrg  = "cloudeq-emu-org"
    method = "terraform"
  }
}
################################################################################
# EKS Module
################################################################################

module "eks" {
  source = "./modules/eks"

  cluster_name                   = local.name
  cluster_version                = local.cluster_version
  cluster_endpoint_public_access = true

  # Gives Terraform identity admin access to cluster which will
  # allow deploying resources (Karpenter) into the cluster
  enable_cluster_creator_admin_permissions = true

  cluster_addons = {
    coredns = {
      configuration_values = jsonencode({
        computeType = "Fargate"
        resources = {
        limits = {
          cpu = "0.25"
          # We are targeting the smallest Task size of 512Mb, so we subtract 256Mb from the
          # request/limit to ensure we can fit within that task
          memory = "256M"
        }
        requests = {
          cpu = "0.25"
          # We are targeting the smallest Task size of 512Mb, so we subtract 256Mb from the
          # request/limit to ensure we can fit within that task
          memory = "256M"
        }
          }
            })
                }
    kube-proxy = {
      most_recent        = true
    }
    vpc-cni    = {
    most_recent        = true
    }
  }

  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnets
  control_plane_subnet_ids = module.vpc.intra_subnets

  # Fargate profiles use the cluster primary security group so these are not utilized
  create_cluster_security_group = false
  create_node_security_group    = false

fargate_profiles = {
    karpenter = {
      name = "karpernter"
      selectors = [
        { namespace = "karpenter"  }
      ]
    }
    kube-system = {
      name = "kube-system"
      selectors = [
        { namespace = "kube-system" }
      ]
    }
  }


  tags = merge(local.tags, {
    # NOTE - if creating multiple security groups with this module, only tag the
    # security group that Karpenter should utilize with the following tag
    # (i.e. - at most, only one security group should have this tag in your account)
    "karpenter.sh/discovery" = local.name
  })
}

#Ebs addon

data "aws_iam_policy" "ebs_csi_policy" {
  arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

module "irsa-ebs-csi" {
  source  = "./modules/iam-assumable-role-with-oidc"
  create_role                   = true
  role_name                     = "AmazonEKSTFEBSCSIRole-${module.eks.cluster_name}"
  provider_url                  = module.eks.oidc_provider
  role_policy_arns              = [data.aws_iam_policy.ebs_csi_policy.arn]
  oidc_fully_qualified_subjects = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
}

resource "aws_eks_addon" "ebs-csi" {
  cluster_name             = module.eks.cluster_name
  addon_name               = "aws-ebs-csi-driver"
  addon_version            = "v1.28.0-eksbuild.1"
  service_account_role_arn = module.irsa-ebs-csi.iam_role_arn
  tags = {
    "eks_addon" = "ebs-csi"
    "terraform" = "true"
  }
}
################################################################################
# Karpenter
################################################################################

module "karpenter" {
  source = "./modules/karpenter"

  cluster_name = module.eks.cluster_name

  # EKS Fargate currently does not support Pod Identity
  enable_irsa            = true
  irsa_oidc_provider_arn = module.eks.oidc_provider_arn

  # Used to attach additional IAM policies to the Karpenter node IAM role
  node_iam_role_additional_policies = {
    AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }

  tags = local.tags
}

################################################################################
# Karpenter Helm chart & manifests
# Not required; just to demonstrate functionality of the sub-module
################################################################################


################################################################################
# Argo helm
################################################################################
#module "argocd_helm" {
#  source = "./modules/argocd"

#  cluster_identity_oidc_issuer     = module.eks.cluster_oidc_issuer_url
#  cluster_identity_oidc_issuer_arn = module.eks.eks_cluster_identity_oidc_issuer_arn

 # enabled           = true
 # argo_enabled      = false
 # argo_helm_enabled = false

 # self_managed = false

 # helm_release_name = "argocd"
 # namespace         = "argocd"

#  helm_timeout = 240
#  helm_wait    = true

#}
