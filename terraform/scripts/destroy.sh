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

echo "✓ Required tools found."

# ------------------------------------------------------------
# AWS authentication
# ------------------------------------------------------------

print_banner "AWS Authentication"

aws sts get-caller-identity

echo "✓ AWS credentials verified."

# ------------------------------------------------------------
# Confirmation
# ------------------------------------------------------------

print_banner "EKS Platform Destruction"

echo "WARNING: This will destroy the Terraform-managed EKS platform."
echo
read -r -p "Are you sure you want to continue? Type 'yes' to proceed: " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
  echo "Destroy cancelled."
  exit 0
fi

# ------------------------------------------------------------
# Terraform configuration
# ------------------------------------------------------------

cd "$TERRAFORM_DIR"

terraform fmt -recursive
terraform validate

echo "✓ Terraform configuration validated."

# ------------------------------------------------------------
# Check EKS cluster
# ------------------------------------------------------------

print_banner "Checking EKS Cluster"

EKS_STATUS="$(
  aws eks describe-cluster \
    --name "$CLUSTER_NAME" \
    --region "$AWS_REGION" \
    --query 'cluster.status' \
    --output text \
    2>/dev/null || true
)"

CLUSTER_EXISTS=false

if [[ -n "$EKS_STATUS" && "$EKS_STATUS" != "None" && "$EKS_STATUS" != "DELETING" ]]; then
  CLUSTER_EXISTS=true
  echo "EKS cluster status: $EKS_STATUS"
else
  echo "EKS cluster is not available."
fi

# ------------------------------------------------------------
# Kubernetes cleanup
#
# ArgoCD owns the Kubernetes platform workloads. Remove the
# root Application first so ArgoCD stops reconciling Git state.
# ------------------------------------------------------------

if [[ "$CLUSTER_EXISTS" == true ]]; then

  print_banner "Stopping ArgoCD Reconciliation"

  if kubectl cluster-info >/dev/null 2>&1; then

    kubectl delete application platform-root \
      -n argocd \
      --ignore-not-found=true

    echo "✓ platform-root deletion requested."

    echo
    echo "Waiting for ArgoCD child Applications to disappear..."

    for application in \
      e-commerce-dev \
      e-commerce-prod \
      postgres \
      redis \
      secrets \
      storage \
      monitoring
    do
      kubectl wait \
        --for=delete \
        "application/$application" \
        -n argocd \
        --timeout=120s \
        2>/dev/null || true
    done

    echo "✓ ArgoCD Applications released."

  else

    echo "WARNING: Kubernetes API is unavailable."
    echo "Skipping Kubernetes cleanup."

  fi
fi

# ------------------------------------------------------------
# Terraform destroy plan
# ------------------------------------------------------------

print_banner "Terraform Destroy Plan"

terraform plan -destroy -out=destroy.tfplan

echo
echo "Terraform destroy plan created."
echo
read -r -p "Apply this destroy plan? Type 'yes' to proceed: " DESTROY_CONFIRM

if [ "$DESTROY_CONFIRM" != "yes" ]; then
  rm -f destroy.tfplan
  echo "Destroy cancelled."
  exit 0
fi

# ------------------------------------------------------------
# Terraform destroy
# ------------------------------------------------------------

print_banner "Terraform Destroy"

terraform apply -auto-approve destroy.tfplan

rm -f destroy.tfplan

echo "✓ Terraform infrastructure destroyed."

# ------------------------------------------------------------
# Terraform state verification
# ------------------------------------------------------------

print_banner "Terraform State Verification"

TERRAFORM_STATE="$(terraform state list 2>/dev/null || true)"

if [[ -n "$TERRAFORM_STATE" ]]; then
  echo "ERROR: Terraform state is not empty:"
  echo
  echo "$TERRAFORM_STATE"
  exit 1
fi

echo "✓ Terraform state is empty."

# ------------------------------------------------------------
# AWS verification
# ------------------------------------------------------------

print_banner "AWS Cleanup Verification"

echo "Remaining EKS clusters:"
aws eks list-clusters \
  --region "$AWS_REGION"

echo
echo "Remaining Jenkins VPCs:"
aws ec2 describe-vpcs \
  --region "$AWS_REGION" \
  --filters "Name=tag:Name,Values=jenkins-vpc" \
  --query 'Vpcs[].VpcId' \
  --output text

echo
echo "Remaining Load Balancers:"
aws elbv2 describe-load-balancers \
  --region "$AWS_REGION" \
  --query 'LoadBalancers[].LoadBalancerArn' \
  --output text

echo
echo "Remaining EKS CloudWatch log groups:"
aws logs describe-log-groups \
  --region "$AWS_REGION" \
  --log-group-name-prefix "/aws/eks/$CLUSTER_NAME" \
  --query 'logGroups[].logGroupName' \
  --output text

# ------------------------------------------------------------
# Final status
# ------------------------------------------------------------

print_banner "Destroy Successful"

echo "Terraform-managed EKS infrastructure has been destroyed."
echo
echo "AWS cleanup verification completed."
echo
echo "The GitOps-managed Kubernetes workloads were released before"
echo "Terraform destruction."
