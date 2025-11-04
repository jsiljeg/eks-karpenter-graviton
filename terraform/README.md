# EKS + Karpenter (dual-arch Spot) — Terraform, split modules

This repo matches the requested layout and splits concerns into three stacks:

```
environments/development/aws/eu-central-1/
  ├─ terraform-state-infra   # creates S3 bucket + DynamoDB table for remote state
  ├─ init-setup              # creates VPC, subnets, NAT, node security group
  └─ eks-karpenter           # creates EKS, installs Karpenter, dual-arch NodePools
modules/
  ├─ terraform-state-infra
  ├─ init-setup
  └─ eks-karpenter
```

## Prereqs

- Terraform >= 1.6
- AWS CLI configured with credentials that can create IAM, VPC, S3, DynamoDB, EKS, EC2, EventBridge, SQS
- `kubectl`, `helm`

Authenticate (examples):
```bash
# Option A: use a named profile set by 'aws configure'
export AWS_PROFILE=myadmin
export AWS_REGION=eu-central-1

# Option B: env vars
export AWS_ACCESS_KEY_ID=...
export AWS_SECRET_ACCESS_KEY=...
export AWS_REGION=eu-central-1
```

## Order of operations

> Region used below is `eu-central-1` and env is `development` (already set in each stack).

1) **State backend** — create once per account/env
```
cd environments/development/aws/eu-central-1/terraform-state-infra
terraform init
terraform apply
```
Outputs: S3 bucket and DynamoDB table names for remote state.

2) **Init setup (networking + SG)** — now that backend exists, this stack already uses it.
```
cd ../init-setup
# Create a terraform.tfvars if you want to override defaults (CIDR, AZ count, etc.)
terraform init
terraform apply
```
Outputs: VPC ID, private/public subnets, node security group.

3) **EKS + Karpenter**
```
cd ../eks-karpenter
terraform init
terraform apply
```
This installs the cluster and Karpenter. After apply:
```
aws eks update-kubeconfig --region $(terraform output -raw region) --name $(terraform output -raw cluster_name)
kubectl get nodes -o wide
```

## Run sample workloads on x86 vs Graviton

```
kubectl apply -f modules/eks-karpenter/examples/deploy-amd64-spot.yaml
kubectl apply -f modules/eks-karpenter/examples/deploy-arm64-spot.yaml

kubectl get pods -o wide -l app=amd64-spot-demo
kubectl get pods -o wide -l app=arm64-spot-demo
```

## Clean up

Destroy in reverse order (start with eks-karpenter). Ensure no nodes/LBs remain.
```bash
cd environments/development/aws/eu-central-1/eks-karpenter && terraform destroy
cd ../init-setup && terraform destroy
# Destroy backend LAST if you want to remove everything
cd ../terraform-state-infra && terraform destroy
```

> **Cost note**: EKS control plane, NAT gateway, and EC2 instances are **not free**.
