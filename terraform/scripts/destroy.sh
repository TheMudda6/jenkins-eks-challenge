#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_ROOT/terraform"

set -euo pipefail

trap 'echo ""; echo "ERROR: Cleanup failed on line $LINENO"; exit 1' ERR

export AWS_PAGER=""

# --------------------------------------------------------------------
# Cleanup Configuration
#
# Purpose:
# Centralise values that may change between environments.
# --------------------------------------------------------------------

AWS_REGION="eu-west-2"
CLUSTER_NAME="jenkins-eks"
NAMESPACE="jenkins"

# --------------------------------------------------------------------
# Helper Functions
#
# Purpose:
# Reusable functions used throughout the cleanup.
# --------------------------------------------------------------------

print_banner() {
    echo
    echo "====================================="
    echo "$1"
    echo "====================================="
    echo
}

# --------------------------------------------------------------------
# Prerequisite Checks
#
# Purpose:
# Verify all required tools are installed before cleanup begins.
# --------------------------------------------------------------------

command -v terraform >/dev/null || { echo "ERROR: Terraform is not installed."; exit 1; }
command -v aws >/dev/null || { echo "ERROR: AWS CLI is not installed."; exit 1; }
command -v kubectl >/dev/null || { echo "ERROR: kubectl is not installed."; exit 1; }

echo "✓ All prerequisites found."

# --------------------------------------------------------------------
# AWS Authentication Check
#
# Purpose:
# Verify AWS credentials are valid before destroying infrastructure.
# --------------------------------------------------------------------

echo "Verifying AWS credentials..."

aws sts get-caller-identity

echo "✓ AWS credentials verified."

print_banner "Starting Jenkins EKS Cleanup"

echo "WARNING: This will destroy the entire Jenkins EKS environment."

read -p "Are you sure you want to continue? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Cleanup cancelled."
    exit 0
fi

# --------------------------------------------------------------------
# Kubernetes Cleanup
#
# Purpose:
# Remove Kubernetes resources before destroying infrastructure.
# --------------------------------------------------------------------

print_banner "Cleaning Kubernetes Resources"

echo "Checking cluster connectivity..."

kubectl get nodes

echo "Deleting Jenkins ingress..."

kubectl delete -f k8s/jenkins-ingress.yaml --ignore-not-found=true

echo "✓ Jenkins ingress deleted."

echo "Waiting for AWS Load Balancer cleanup..."

sleep 120

echo "Deleting Jenkins service..."

kubectl delete -f k8s/jenkins-service.yaml --ignore-not-found=true

echo "✓ Jenkins service deleted."

echo "Deleting Jenkins deployment..."

kubectl delete -f k8s/jenkins-deployment.yaml --ignore-not-found=true

echo "✓ Jenkins deployment deleted."

echo "Deleting Jenkins PVC..."

kubectl delete -f k8s/jenkins-pvc.yaml --ignore-not-found=true

echo "✓ Jenkins PVC deleted."

echo "Deleting Jenkins namespace..."

kubectl delete namespace "$NAMESPACE" --ignore-not-found=true

echo "Waiting for namespace deletion..."

kubectl wait \
  --for=delete namespace/"$NAMESPACE" \
  --timeout=120s || true

echo "✓ Namespace removed."

echo ""
echo "Remaining cluster resources:"
kubectl get pods -A || true

# --------------------------------------------------------------------
# Snapshot Infrastructure Cleanup
#
# Purpose:
# Remove all Kubernetes snapshot resources before destroying the cluster.
# --------------------------------------------------------------------

print_banner "Removing Snapshot Infrastructure"

bash k8s/snapshot/uninstall.sh

echo "✓ Snapshot infrastructure removed."

# ------------------------------------------------------------
# Storage Cleanup
#
# Purpose:
# Remove cluster storage resources before destroying the cluster.
# ------------------------------------------------------------
# GP3 StorageClass Cleanup
# gp3-retain, gp3, VolumeSnapshotClass

echo "Deleting gp3-retain StorageClass..."
kubectl delete -f k8s/storage/gp3-retain-storageclass.yaml --ignore-not-found=true

echo "✓ gp3-retain StorageClass deleted."

echo "Deleting gp3 StorageClass..."
kubectl delete -f k8s/storage/gp3-storageclass.yaml --ignore-not-found=true

echo "✓ gp3 StorageClass deleted."

# --------------------------------------------------------------------
# Terraform Cleanup
#
# Purpose:
# Review and destroy Terraform-managed infrastructure.
# --------------------------------------------------------------------

print_banner "Terraform Cleanup"

echo "Validating Terraform configuration..."

terraform validate

echo "✓ Terraform validation complete."

echo "Creating Terraform destroy plan..."

terraform plan -destroy -out=destroy.tfplan

echo "✓ Terraform destroy plan created."

read -p "Proceed with Terraform destroy? (yes/no): " destroy_confirm

if [ "$destroy_confirm" != "yes" ]; then
    echo "Cleanup cancelled."
    exit 0
fi

echo "Destroying Terraform infrastructure..."

terraform apply destroy.tfplan

echo "✓ Terraform infrastructure destroyed."

# --------------------------------------------------------------------
# Cleanup Verification
#
# Purpose:
# Verify AWS resources have been successfully removed.
# --------------------------------------------------------------------

print_banner "Cleanup Verification"

echo "Checking for remaining EKS clusters..."

aws eks list-clusters --region "$AWS_REGION"

echo "Checking for remaining VPCs..."

aws ec2 describe-vpcs \
  --filters Name=tag:Name,Values=jenkins-vpc \
  --region "$AWS_REGION"

echo "Checking for remaining Load Balancers..."

aws elbv2 describe-load-balancers \
  --region "$AWS_REGION"

echo "Checking for remaining CloudWatch log groups..."

aws logs describe-log-groups \
  --log-group-name-prefix "/aws/eks/$CLUSTER_NAME" \
  --region "$AWS_REGION"

echo "Checking for remaining EBS volumes..."

aws ec2 describe-volumes \
  --region "$AWS_REGION" \
  --filters Name=tag:KubernetesCluster,Values="$CLUSTER_NAME"

echo ""
echo "Checking for remaining VolumeSnapshotClasses..."

kubectl get volumesnapshotclass 2>/dev/null || echo "✓ No VolumeSnapshotClasses found."

echo ""
echo "Checking for remaining VolumeSnapshots..."

kubectl get volumesnapshot -A 2>/dev/null || echo "✓ No VolumeSnapshots found."

echo ""
echo "Checking for remaining VolumeSnapshotContents..."

kubectl get volumesnapshotcontent 2>/dev/null || echo "✓ No VolumeSnapshotContents found."

echo ""
echo "Checking Snapshot Controller..."

kubectl get deployment snapshot-controller -n kube-system 2>/dev/null || echo "✓ Snapshot Controller removed."

echo ""
echo "Checking Snapshot CRDs..."

kubectl get crd | grep snapshot || echo "✓ No Snapshot CRDs found."

echo "Removing orphaned CloudWatch log group if present..."

aws logs delete-log-group \
  --log-group-name "/aws/eks/${CLUSTER_NAME}/cluster" \
  --region "$AWS_REGION" 2>/dev/null || true

echo "✓ Verification complete."

echo ""
echo "Cleaning temporary Terraform files..."

rm -f tfplan destroy.tfplan

echo "✓ Temporary Terraform files removed."
echo ""

print_banner "Cleanup Complete!"