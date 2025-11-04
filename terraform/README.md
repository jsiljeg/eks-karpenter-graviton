# Terraform: VPC + EKS + Karpenter

This folder contains the Infrastructure as Code to provision a fresh AWS network + EKS cluster, and to install Karpenter with sane defaults.

---

## Layout

```
terraform/
├─ modules/
│  ├─ eks-karpenter/          # EKS cluster + IRSA + Karpenter controller + IAM + supporting infra
│  ├─ init-setup/             # bootstrap: S3 bucket, DynamoDB table, networking prerequisites
│  └─ terraform-state-infra/  # remote state storage infrastructure (S3 backend + DynamoDB lock)
└─ environments/
   └─ development/
      └─ aws/
         └─ eu-central-1/
            ├─ terraform-state-infra/  # creates S3 + DynamoDB for Terraform remote state
            ├─ init-setup/             # creates baseline VPC, subnets, and shared resources
            └─ eks-karpenter/          # creates the EKS cluster, installs Karpenter, etc.
```

---

## Folder responsibilities

### 🧱 `terraform-state-infra`
This folder provisions the **remote state backend** used by the rest of the Terraform configurations.  
It ensures that all future Terraform runs share the same consistent, locked state.

**Creates:**
- An S3 bucket (e.g. `of-practice-development-eu-central-1-tfstate`)
- A DynamoDB table (e.g. `of-practice-development-tf-lock`) for state locking

**Why it exists:**
Without this, multiple developers or CI jobs could corrupt or overwrite each other’s state files.  
It’s run **once per environment/region** and referenced by the other stacks via `backend "s3"` blocks.

> Run this first:  
> ```bash
> cd terraform/environments/development/aws/eu-central-1/terraform-state-infra
> terraform init && terraform apply -auto-approve
> ```

---

### ⚙️ `init-setup`
This layer bootstraps shared AWS network resources **before** deploying EKS.  
It sets up foundational components that all workloads depend on.

**Creates:**
- A new VPC with private/public subnets  
- Route tables, NAT Gateway, and Internet Gateway  
- Optional IAM roles or security groups shared by the cluster  
- Outputs for `vpc_id`, `private_subnets`, `public_subnets`, and security groups

**Why it exists:**
Terraform modules like EKS and Karpenter need to reference a working network and VPC ID.  
This step keeps your cluster configuration modular — networking can evolve independently.

> Run this second:  
> ```bash
> cd terraform/environments/development/aws/eu-central-1/init-setup
> terraform init && terraform apply -auto-approve
> ```

---

### ☸️ `eks-karpenter`
This is the **main layer** that depends on the outputs from `init-setup`.  
It deploys the EKS cluster, Karpenter controller, IAM roles, and CRDs.

**Creates:**
- EKS control plane and managed node group for system pods  
- IAM roles for Karpenter controller and nodes  
- Karpenter CRDs and Helm releases (`karpenter`, `karpenter-crd`)  
- Example NodePools (arm64 + amd64)

**Why it exists:**
This layer is where compute and autoscaling behavior is defined.  
Developers or CI pipelines typically interact only with this directory.

> Run this third:  
> ```bash
> cd terraform/environments/development/aws/eu-central-1/eks-karpenter
> terraform init && terraform apply -auto-approve
> ```

---

## Variables (environment)

See `variables.tf` in the `eks-karpenter` folder. Typical inputs:

| Variable | Description | Example |
|-----------|--------------|----------|
| `region` | AWS region | `eu-central-1` |
| `cluster_name` | Cluster name | `eks-karpenter-poc` |
| `system_mng_desired_size` | Managed nodegroup size | `2` |
| `system_ng_in_public` | Whether system nodes live in public subnets | `true` |

---

## Karpenter: dual-arch pools

- **x86 NodePool** → `kubernetes.io/arch = amd64` (Intel/AMD)
- **arm64 NodePool** → `kubernetes.io/arch = arm64` (Graviton)
- Both can use `karpenter.sh/capacity-type: spot` or `on-demand`

Your workloads can target these pools with simple selectors:

```yaml
nodeSelector:
  kubernetes.io/arch: arm64
  karpenter.sh/capacity-type: spot
```

---

## Apply order

```
1️⃣ terraform-state-infra   → creates S3 + DynamoDB for remote state
2️⃣ init-setup              → creates base VPC/subnets
3️⃣ eks-karpenter           → creates cluster + Karpenter
```

---

## Destroy order

```
3️⃣ eks-karpenter
2️⃣ init-setup
1️⃣ terraform-state-infra   (only if you want to remove backend)
```

> Always destroy in reverse order to avoid dependency errors.

---

## Troubleshooting

| Symptom | Likely Cause | Fix |
|----------|--------------|-----|
| `Error acquiring state lock` | DynamoDB table missing or deleted | Recreate `terraform-state-infra` |
| `NodeCreationFailure` | Wrong subnet or missing IAM policy | Re-run `init-setup` and `eks-karpenter` |
| `terraform init` re-downloads providers | Cache miss in pipeline | Check plugin cache key or `~/.terraform.d` path |

---

## #TODO ideas

- Add **Cross-Account** remote state (for multi-team setups)
- Add **Shared VPC** output exports for future stacks
- Include **OpenTofu** compatibility note
