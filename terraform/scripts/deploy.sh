#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$(dirname "$SCRIPT_DIR")"

AWS_REGION="eu-west-2"
CLUSTER_NAME="jenkins-eks"

print_banner() {
  echo
  echo "====================================="
  echo "$1"
  echo "====================================="
  echo
}

# ------------------------------------------------------------
# Prerequisites
# ------------------------------------------------------------

command -v terraform >/dev/null || {
  echo "ERROR: Terraform is not installed."
  exit 1
}

command -v aws >/dev/null || {
  echo "ERROR: AWS CLI is not installed."
  exit 1
}

command -v kubectl >/dev/null || {
  echo "ERROR: kubectl is not installed."
  exit 1
}

command -v helm >/dev/null || {
  echo "ERROR: Helm is not installed."
  exit 1
}

echo "✓ Required tools found."

# ------------------------------------------------------------
# AWS authentication
# ------------------------------------------------------------

print_banner "AWS Authentication"

aws sts get-caller-identity

echo "✓ AWS credentials verified."

# ------------------------------------------------------------
# Terraform validation
# ------------------------------------------------------------

cd "$TERRAFORM_DIR"

print_banner "Terraform Validation"

terraform fmt -recursive
terraform validate

echo "✓ Terraform configuration validated."

# ------------------------------------------------------------
# Terraform plan
# ------------------------------------------------------------

print_banner "Terraform Plan"

terraform plan -out=tfplan

echo
echo "Terraform plan created successfully."
echo
echo "Review the plan above before continuing."
echo
read -r -p "Apply this Terraform plan? [y/N] " CONFIRM

if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
  echo "Terraform apply cancelled."
  rm -f tfplan
  exit 0
fi

# ------------------------------------------------------------
# Terraform apply
# ------------------------------------------------------------

print_banner "Terraform Apply"

terraform apply tfplan

rm -f tfplan

echo "✓ Terraform apply complete."

# ------------------------------------------------------------
# Kubernetes configuration
# ------------------------------------------------------------

print_banner "Configuring Kubernetes"

aws eks update-kubeconfig \
  --region "$AWS_REGION" \
  --name "$CLUSTER_NAME"

kubectl get nodes

echo "✓ Kubernetes connectivity verified."

# ------------------------------------------------------------
# Verify platform controllers
# ------------------------------------------------------------

print_banner "Verifying Platform Controllers"

kubectl wait \
  --for=condition=Available \
  deployment/argocd-server \
  -n argocd \
  --timeout=300s

echo "✓ ArgoCD is ready."

echo "Installing Volume Snapshot infrastructure..."
bash infrastructure/snapshot/install.sh
echo "✓ Volume Snapshot infrastructure ready."

kubectl apply -f infrastructure/argocd/root-application.yaml

echo "✓ ArgoCD platform-root Application applied."

kubectl wait \
  --for=condition=Available \
  deployment/karpenter \
  -n kube-system \
  --timeout=300s

echo "✓ Karpenter is ready."

kubectl wait \
  --for=condition=Available \
  deployment/aws-load-balancer-controller \
  -n kube-system \
  --timeout=300s

echo "✓ AWS Load Balancer Controller is ready."

kubectl wait \
  --for=condition=Available \
  deployment/ebs-csi-controller \
  -n kube-system \
  --timeout=300s

echo "✓ EBS CSI controller is ready."

kubectl wait \
  --for=condition=Available \
  deployment/external-secrets \
  -n external-secrets \
  --timeout=300s

echo "✓ External Secrets Operator is ready."

# ------------------------------------------------------------
# Verify ArgoCD GitOps root application
# ------------------------------------------------------------

print_banner "Verifying ArgoCD GitOps"

echo "Waiting for platform-root Application..."

ARGOCD_TIMEOUT=300
ARGOCD_ELAPSED=0

until kubectl get application platform-root \
  -n argocd \
  -o jsonpath='{.status.sync.status} {.status.health.status}' 2>/dev/null \
  | grep -q "Synced Healthy"; do

  if [ "$ARGOCD_ELAPSED" -ge "$ARGOCD_TIMEOUT" ]; then
    echo "ERROR: platform-root did not become Synced Healthy."
    kubectl get application platform-root -n argocd
    exit 1
  fi

  echo "Waiting for platform-root..."
  sleep 10
  ARGOCD_ELAPSED=$((ARGOCD_ELAPSED + 10))
done

echo "✓ platform-root is Synced and Healthy."

# ------------------------------------------------------------
# Verify child Applications
# ------------------------------------------------------------

print_banner "Verifying ArgoCD Applications"

kubectl get applications -n argocd

echo
echo "Checking required Applications..."

for application in \
  e-commerce-dev \
  e-commerce-prod \
  postgres \
  redis \
  secrets \
  storage \
  monitoring
do
  if ! kubectl get application "$application" -n argocd >/dev/null 2>&1; then
    echo "ERROR: ArgoCD Application '$application' was not created."
    exit 1
  fi

  echo "✓ $application"
done

# ------------------------------------------------------------
# Verify application workloads
# ------------------------------------------------------------

print_banner "Verifying E-Commerce Platform"

echo "Waiting for PostgreSQL..."

kubectl wait \
  --for=condition=Ready \
  pod/postgres-0 \
  -n jenkins \
  --timeout=300s

echo "✓ PostgreSQL is ready."

echo
echo "Waiting for Redis..."

kubectl wait \
  --for=condition=Available \
  deployment/redis \
  -n jenkins \
  --timeout=300s

echo "✓ Redis is ready."

echo
echo "Application deployments:"

kubectl get deployments -n jenkins

echo
echo "Application pods:"

kubectl get pods -n jenkins

echo
echo "Application services:"

kubectl get services -n jenkins

# ------------------------------------------------------------
# Verify monitoring
# ------------------------------------------------------------

print_banner "Verifying Monitoring"

kubectl get servicemonitors -n monitoring

kubectl get prometheusrules -n monitoring

kubectl get pods -n monitoring

echo "✓ Monitoring resources verified."

# ------------------------------------------------------------
# Final platform status
# ------------------------------------------------------------

print_banner "Final Platform Status"

echo "ArgoCD Applications:"
kubectl get applications -n argocd

echo
echo "EKS Nodes:"
kubectl get nodes

echo
echo "Namespaces:"
kubectl get namespaces

echo
echo "Storage:"
kubectl get storageclass

echo
echo "PostgreSQL:"
kubectl get statefulset,pod,pvc -n jenkins

echo
echo "Redis:"
kubectl get deployment,pod -n jenkins -l app=redis

echo
echo "E-Commerce Services:"
kubectl get deployment,service -n jenkins

echo
echo "Monitoring:"
kubectl get pods -n monitoring

print_banner "Deployment Successful"

echo "EKS platform and GitOps stack are ready."
echo
echo "Application workloads are managed by ArgoCD."
echo "Application deployments should be triggered through Git commits."
echo
echo "Use destroy.sh when the environment is no longer required."