# Examples: dual‑arch deployments

This folder contains tiny Deployments to demonstrate how a developer can pick **x86_64 (amd64)** or **arm64 (Graviton)** nodes simply by setting a label.

- `deploy-amd64.yaml` → `nodeSelector: kubernetes.io/arch: amd64`
- `deploy-arm64.yaml` → `nodeSelector: kubernetes.io/arch: arm64`
- `deploy-generic.yaml` → no arch specified; Karpenter can choose either

## How to use (from GitHub Actions)

Run **Actions → Deploy Karpenter Examples** and set the `file` input to one of the above. Optionally change the `namespace`. Click **Run workflow**.

## How to use (from local shell)

```bash
aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$AWS_REGION"

kubectl apply -f examples/dual-arch/deploy-arm64.yaml
kubectl get pods -o wide
kubectl get nodes -L kubernetes.io/arch,karpenter.sh/capacity-type
```

You should see Karpenter launch the matching capacity and place the pod accordingly.
