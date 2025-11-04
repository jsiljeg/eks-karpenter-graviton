# terraform/environments/development/aws/eu-central-1/eks-karpenter/karpenter.tf

###########
# Prep kubeconfig so local-exec kubectl always works (even on Windows CI)
###########
# Namespace via Kubernetes provider
resource "kubernetes_namespace" "karpenter" {
  metadata {
    name = "karpenter"
  }
  depends_on = [module.eks_karpenter]
}

# CRDs chart
resource "helm_release" "karpenter_crd" {
  name            = "karpenter-crd"
  chart           = "oci://public.ecr.aws/karpenter/karpenter-crd"
  version         = var.karpenter_version
  namespace       = kubernetes_namespace.karpenter.metadata[0].name
  cleanup_on_fail = true
  create_namespace = true
  wait            = true
  timeout         = 1200


  depends_on = [
    module.eks_karpenter,
    #kubernetes_namespace.karpenter,
    #aws_eks_node_group.system,
    aws_eks_addon.vpc_cni,
    aws_eks_addon.kube_proxy,
    aws_eks_addon.coredns,
    aws_eks_addon.pod_identity_agent #<--- added
  ]
}

# Main controller
resource "helm_release" "karpenter" {
  name            = "karpenter"
  chart           = "oci://public.ecr.aws/karpenter/karpenter"
  version         = var.karpenter_version
  namespace       = kubernetes_namespace.karpenter.metadata[0].name
  cleanup_on_fail = true
  create_namespace = true
  wait            = true
  timeout         = 1200
  force_update = true   # ensure a fresh rollout on values change

  values = [
    yamlencode({
      # EXACT keys per chart values.yaml (lowerCamelCase)
      featureGates = {
        reservedCapacity        = true
        spotToSpotConsolidation = false
        nodeRepair              = false
        nodeOverlay             = false
        staticCapacity          = false
      }

      settings = {
        clusterName            = module.eks_karpenter.cluster_name
        clusterEndpoint        = module.eks_karpenter.cluster_endpoint
        interruptionQueue      = module.eks_karpenter.karpenter_interruptions_queue_name
        defaultInstanceProfile = module.eks_karpenter.karpenter_node_instance_profile_name
      }

      serviceAccount = {
        name = "karpenter"
        annotations = {
          "eks.amazonaws.com/role-arn" = module.eks_karpenter.karpenter_controller_role_arn
        }
      }

      replicas = 2
    })
  ]

  depends_on = [helm_release.karpenter_crd]
  /*
  depends_on = [
    helm_release.karpenter_crd,
    aws_eks_node_group.system,
    aws_eks_addon.vpc_cni,
    aws_eks_addon.kube_proxy,
    aws_eks_addon.coredns,
  ]

   */
}


# render your instance-type lists (reuse your locals)
locals {
  amd64_values_block = "- ${join("\n          - ", var.amd64_instance_types)}"
  arm64_values_block = "- ${join("\n          - ", var.arm64_instance_types)}"
}

# EC2NodeClass (amd64)
resource "kubectl_manifest" "nc_amd64" {
  yaml_body = <<-YAML
apiVersion: karpenter.k8s.aws/v1
kind: EC2NodeClass
metadata:
  name: nc-amd64
spec:
  amiFamily: Bottlerocket
  amiSelectorTerms:
    - ssmParameter: /aws/service/bottlerocket/aws-k8s-${var.eks_version}/x86_64/latest/image_id
  instanceProfile: ${module.eks_karpenter.karpenter_node_instance_profile_name}
  subnetSelectorTerms:
    - tags:
        karpenter.sh/discovery: ${module.eks_karpenter.cluster_name}
  securityGroupSelectorTerms:
    - tags:
        karpenter.sh/discovery: ${module.eks_karpenter.cluster_name}
  tags:
    karpenter.sh/discovery: ${module.eks_karpenter.cluster_name}
YAML

  depends_on = [helm_release.karpenter]
}

# EC2NodeClass (arm64)
resource "kubectl_manifest" "nc_arm64" {
  yaml_body = <<-YAML
apiVersion: karpenter.k8s.aws/v1
kind: EC2NodeClass
metadata:
  name: nc-arm64
spec:
  amiFamily: Bottlerocket
  amiSelectorTerms:
    - ssmParameter: /aws/service/bottlerocket/aws-k8s-${var.eks_version}/arm64/latest/image_id
  instanceProfile: ${module.eks_karpenter.karpenter_node_instance_profile_name}
  subnetSelectorTerms:
    - tags:
        karpenter.sh/discovery: ${module.eks_karpenter.cluster_name}
  securityGroupSelectorTerms:
    - tags:
        karpenter.sh/discovery: ${module.eks_karpenter.cluster_name}
  tags:
    karpenter.sh/discovery: ${module.eks_karpenter.cluster_name}
YAML

  depends_on = [helm_release.karpenter]
}

# NodePool (amd64)
resource "kubectl_manifest" "np_amd64" {
  yaml_body = <<-YAML
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: np-amd64-spot
spec:
  disruption:
    consolidationPolicy: WhenEmptyOrUnderutilized
    consolidateAfter: 30s
  limits:
    cpu: "10"
  template:
    metadata:
      labels:
        karpenter.sh/capacity-type: ${var.capacity_type}
        kubernetes.io/arch: amd64
    spec:
      nodeClassRef:
        group: karpenter.k8s.aws
        kind: EC2NodeClass
        name: nc-amd64
      requirements:
        - key: kubernetes.io/arch
          operator: In
          values: [ "amd64" ]
        - key: karpenter.sh/capacity-type
          operator: In
          values: [ "${var.capacity_type}" ]
        - key: node.kubernetes.io/instance-type
          operator: In
          values:
          ${local.amd64_values_block}
      expireAfter: 720h
YAML

  depends_on = [kubectl_manifest.nc_amd64]
}

# NodePool (arm64)
resource "kubectl_manifest" "np_arm64" {
  yaml_body = <<-YAML
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: np-arm64-spot
spec:
  disruption:
    consolidationPolicy: WhenEmptyOrUnderutilized
    consolidateAfter: 30s
  limits:
    cpu: "10"
  template:
    metadata:
      labels:
        karpenter.sh/capacity-type: ${var.capacity_type}
        kubernetes.io/arch: arm64
    spec:
      nodeClassRef:
        group: karpenter.k8s.aws
        kind: EC2NodeClass
        name: nc-arm64
      requirements:
        - key: kubernetes.io/arch
          operator: In
          values: [ "arm64" ]
        - key: karpenter.sh/capacity-type
          operator: In
          values: [ "${var.capacity_type}" ]
        - key: node.kubernetes.io/instance-type
          operator: In
          values:
          ${local.arm64_values_block}
      expireAfter: 720h
YAML

  depends_on = [kubectl_manifest.nc_arm64]
}


# --- The system managed node group (tiny bootstrap) ---
resource "aws_eks_node_group" "system" {
  cluster_name    = module.eks_karpenter.cluster_name
  node_group_name = "system"
  node_role_arn   = aws_iam_role.system_ng.arn

  subnet_ids     = local.system_ng_subnets          # <-- multiple subnets/AZs
  instance_types = var.system_mng_instance_types    # <-- multiple types

  scaling_config {
    min_size     = var.system_mng_min_size
    desired_size = max(var.system_mng_desired_size, var.system_mng_min_size)
    max_size     = 2
  }

  ami_type      = "BOTTLEROCKET_x86_64"  # switch to AL2_x86_64 if Bottlerocket blocks you
  capacity_type = "ON_DEMAND"
  version       = var.eks_version

  update_config { max_unavailable = 1 }

  tags = {
    "karpenter.sh/discovery"                              = module.eks_karpenter.cluster_name
    "kubernetes.io/cluster/${module.eks_karpenter.cluster_name}" = "owned"
  }
}

##### destroy-ordering.tf

# Wait a bit *during destroy* to let AWS purge control-plane/CNI ENIs
resource "time_sleep" "wait_for_eni_cleanup" {
  # How long to wait on destroy. 8–12 minutes is safe; start with 8m.
  destroy_duration = "8m"

  # Make sure this wait only applies to this cluster
  triggers = {
    cluster = module.eks_karpenter.cluster_name
  }

  # Ensure the wait happens only after the cluster itself is gone
  depends_on = [
    module.eks_karpenter
  ]
}

resource "aws_ec2_tag" "delay_cluster_sg_delete" {
  resource_id = module.eks_karpenter.cluster_security_group_id
  key         = "delete-after-wait"
  value       = "true"

  depends_on = [time_sleep.wait_for_eni_cleanup]
}

resource "aws_ec2_tag" "delay_node_sg_delete" {
  resource_id = module.eks_karpenter.node_security_group_id
  key         = "delete-after-wait"
  value       = "true"

  depends_on = [time_sleep.wait_for_eni_cleanup]
}