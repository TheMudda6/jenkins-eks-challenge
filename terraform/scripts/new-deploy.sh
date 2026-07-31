#!/bin/bash

set -euo pipefail

cleanup() {
    rm -f tfplan destroy.tfplan
}

trap cleanup EXIT
trap 'echo ""; echo "ERROR: Cleanup failed on line $LINENO"; exit 1' ERR

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_ROOT/terraform"

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
# --------------------------------------------------------------------

command -v terraform >/dev/null || { echo "ERROR: Terraform is not installed."; exit 1; }
command -v aws >/dev/null || { echo "ERROR: AWS CLI is not installed."; exit 1; }
command -v kubectl >/dev/null || { echo "ERROR: kubectl is not installed."; exit 1; }

echo "✓ All prerequisites found."

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
# --------------------------------------------------------------------

print_banner "Cleaning Kubernetes Resources"

echo "Checking cluster connectivity..."

kubectl get nodes

echo "✓ Cluster connectivity verified."

echo "Deleting Jenkins ingress..."
kubectl delete -f k8s/jenkins-ingress.yaml --ignore-not-found=true
echo "✓ Jenkins ingress deleted."

echo "Waiting for the AWS Load Balancer to be deleted..."
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
kubectl wait --for=delete namespace/"$NAMESPACE" --timeout=120s || true
echo "✓ Namespace removed."

echo
echo "Remaining cluster resources:"
kubectl get pods -A || true

# --------------------------------------------------------------------
# Snapshot Infrastructure
# --------------------------------------------------------------------

print_banner "Removing Snapshot Infrastructure"

bash k8s/snapshot/uninstall.sh
echo "✓ Snapshot infrastructure removed."

# --------------------------------------------------------------------
# Storage Cleanup
#
# Purpose:
# Remove Kubernetes storage resources before destroying the cluster.
# --------------------------------------------------------------------

print_banner "Removing Storage Resources"

kubectl delete -f k8s/storage/gp3-retain-storageclass.yaml --ignore-not-found=true
echo "✓ gp3-retain StorageClass deleted."

kubectl delete -f k8s/storage/gp3-storageclass.yaml --ignore-not-found=true
echo "✓ gp3 StorageClass deleted."

# --------------------------------------------------------------------
# Terraform Cleanup
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
terraform apply -auto-approve destroy.tfplan
echo "✓ Terraform infrastructure destroyed."

# --------------------------------------------------------------------
# Cleanup Verification
# --------------------------------------------------------------------

print_banner "Cleanup Verification"

echo
echo "Remaining EKS clusters:"
aws eks list-clusters --region "$AWS_REGION"

echo
echo "Remaining VPCs:"
aws ec2 describe-vpcs --filters Name=tag:Name,Values=jenkins-vpc --region "$AWS_REGION"

echo
echo "Remaining Load Balancers:"
aws elbv2 describe-load-balancers --region "$AWS_REGION"

echo
echo "Remaining CloudWatch log groups:"
aws logs describe-log-groups --log-group-name-prefix "/aws/eks/$CLUSTER_NAME" --region "$AWS_REGION"

echo
echo "Remaining EBS volumes:"
aws ec2 describe-volumes --region "$AWS_REGION" --filters Name=tag:KubernetesCluster,Values="$CLUSTER_NAME"

echo
echo "VolumeSnapshotClasses:"
kubectl get volumesnapshotclass 2>/dev/null || echo "✓ No VolumeSnapshotClasses found."

echo
echo "VolumeSnapshots:"
kubectl get volumesnapshot -A 2>/dev/null || echo "✓ No VolumeSnapshots found."

echo
echo "VolumeSnapshotContents:"
kubectl get volumesnapshotcontent 2>/dev/null || echo "✓ No VolumeSnapshotContents found."

echo
echo "Snapshot Controller:"
kubectl get deployment snapshot-controller -n kube-system 2>/dev/null || echo "✓ Snapshot Controller removed."

echo
echo "Snapshot CRDs:"
kubectl get crd | grep snapshot || echo "✓ No Snapshot CRDs found."

aws logs delete-log-group \
  --log-group-name "/aws/eks/${CLUSTER_NAME}/cluster" \
  --region "$AWS_REGION" 2>/dev/null || true

echo "✓ Verification complete."

print_banner "Cleanup Successful"

echo "The Jenkins Platform has been removed successfully."
echo
echo "Terraform-managed infrastructure has been destroyed."
echo
echo "AWS resources have been verified."
echo
echo "Temporary Terraform files have been removed."