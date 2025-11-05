# EKS + Karpenter (x86 + Graviton/arm64) PoC

This repository bootstraps a production‑ready **AWS EKS** cluster in a **dedicated VPC** using **Terraform**, and installs **Karpenter** for fast, cost‑efficient autoscaling. It supports both **x86_64 (AMD/Intel)** and **arm64 (Graviton)** workloads, with **Spot** and **On‑Demand** capacity.

> **Use‑case:** green‑field startup infra with modern autoscaling, great price/performance, and a simple developer flow (via GitHub Actions) to deploy sample workloads onto **either architecture**.

---

## What you get

- ✅ New **VPC** (private subnets, NAT, routing)  
- ✅ **EKS** (latest supported version via module) with required IAM and security groups  
- ✅ **Karpenter** controller + CRDs  
- ✅ **NodePools** (requirements for `amd64` and `arm64`, Spot + On‑Demand)  
- ✅ Example **Deployments** that target either architecture  
- ✅ **GitHub Actions** to: plan/apply Terraform, configure kubeconfig, and deploy manifests

> _Architecture sketch (drop a screenshot here later):_  
> `docs/img/eks-karpenter-arch.png`

---

## Quick start (happy path)

1) **Fork or clone** this repo and set repository secrets (Settings → Secrets and variables → Actions):

| Secret | What |
|---|---|
| `AWS_ACCESS_KEY_ID` | CI user for provisioning |
| `AWS_SECRET_ACCESS_KEY` | CI user secret |
| `AWS_REGION` | e.g. `eu-central-1` |
| `CLUSTER_NAME` | e.g. `eks-karpenter-poc` |

> The IAM user should have permissions to create VPC/EKS/EC2/IAM/SSM/SQS/CloudWatch resources used by Terraform and Karpenter.

2) **Plan** changes (PR to `main` or manual run):
- Workflow: **“(development) EKS Karpenter Terraform Plan”**  
- It runs against `terraform/environments/development/aws/<REGION>/eks-karpenter`
- Caching in place

3) **Apply** changes (merge to `main` or manual run):
- Workflow: **“(development) EKS Karpenter Terraform Apply”**  
- Reconciles the EKS cluster, Karpenter and dependencies.

4) **Deploy an example app** to a specific architecture:
- Workflow: **“Deploy Karpenter Examples”**  
- Input `file`: use one of:
  - `examples/dual-arch/deploy-amd64.yaml` → forces **x86_64**
  - `examples/dual-arch/deploy-arm64.yaml` → forces **arm64/Graviton**
  - `examples/dual-arch/deploy-generic.yaml` → **either**, let Karpenter decide
- Input `namespace`: default `default`

That’s it. Karpenter will create capacity that exactly fits your pod requirements, then scale in aggressively when idle.

---

## How scheduling works (x86 vs arm64, Spot vs On‑Demand)

Kubernetes labels and Karpenter requirements guide placement:

- **By architecture**  
  - Pods specify: `nodeSelector: kubernetes.io/arch: amd64` (or `arm64`)  
  - Karpenter NodePools include matching **requirements** for `kubernetes.io/arch`.
- **By capacity type**  
  - Pods can request Spot vs On‑Demand using:  
    `nodeSelector: karpenter.sh/capacity-type: spot` (or `on-demand`)

See the manifests under `examples/dual-arch`. They demonstrate **minimal changes** to steer placement.

> You can also target a specific NodePool with `nodeSelector: karpenter.sh/nodepool: <name>` if you later split pools by team, SLA, or budget.

---

## Terraform layout

See a focused guide in [`terraform/README.md`](terraform/README.md).  
Highlights:
- **Modules** live in `terraform/modules/*` (VPC, EKS+Karpenter, state-infra, init-setup).
- **Environment** folder: `terraform/environments/development/aws/<region>/eks-karpenter` contains a runnable stack (providers, variables, Karpenter install and IAM).

> The EKS module tracks the **latest** supported cluster version exposed by the module and AWS provider at the time you run it.

---

## GitHub Actions (CI/CD)

See full docs in [`.github/README.md`](.github/README.md).  
You’ll find:
- Reusable **composite actions** to configure AWS, run Terraform, fetch kubeconfig, and apply/delete manifests
- Workflows that **trigger on PRs/pushes** to the Terraform env, plus a **manual** manifest deployer
- A small “**Retry after fail**” helper that can retry failed runs (useful for eventual‑consistency blips)

---

## Developer guide: run a pod on Graviton (arm64)

1. Open **Actions → Deploy Karpenter Examples**  
2. Set **file** to `examples/dual-arch/deploy-arm64.yaml` and click **Run workflow**  
3. Watch the workflow logs; then confirm in a terminal:
   ```bash
   # get kubeconfig (or use the GHA action output)
   aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$AWS_REGION"

   kubectl get nodes -L kubernetes.io/arch,karpenter.sh/capacity-type
   kubectl get pods -o wide
   kubectl describe pod <pod-name> | grep -E 'Node:|kubernetes.io/arch|capacity-type'
   ```

You should see an **arm64** node (generally **Graviton**) launched by Karpenter and your pod scheduled onto it.

---

## Destroy (clean-up)

When you’re done with the POC:
```bash
# from terraform/environments/development/aws/<region>/eks-karpenter
terraform destroy -auto-approve
```
Or run a one‑off job in your CI with the same composite action used for `apply`.

> **Order matters:** delete dependent Karpenter objects first (NodePools, EC2NodeClasses, etc.) if you created custom ones.

---

## Troubleshooting notes

- **NodeCreationFailure / Unhealthy nodes**: often insufficient/blocked subnets, wrong AMI family, or missing Karpenter controller permissions. Verify security groups and IAM policies in `karpenter-iam.tf`.
- **No scale‑up**: check that the Pod has clear `resources.requests`, `kubernetes.io/arch`, and that NodePool requirements are satisfiable (instance families allowed, AZs, capacity type). Inspect `karpenter.sh/events` and controller logs.
- **Can’t kubectl from local**: ensure your IAM principal is mapped via `aws-auth` and that you ran `aws eks update-kubeconfig` with the right region/cluster.

---

## Attributions & license

Licensed under the **MIT License**. See `LICENSE`.

> This repo borrows best‑practices from AWS/Karpenter examples and the EKS Blueprints ecosystem.
