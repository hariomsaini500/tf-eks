  name            = "hss_karpenter_cluster"
  cluster_version = "1.29"
  region          = "eu-north-1"
  vpc_cidr = "10.0.0.0/16"
  
  tags = {
    cluster_name    = "hss_karpenter_cluster"
    GithubRepo = "hhs_eks_infra_optimised"
    GithubOrg  = "cloudeq-emu-org"
    method = "terraform"
  }
