#!/bin/bash

# Terraform provisions:
- AWS infrastructure
- Kubernetes infrastructure

deploy.sh:
- Orchestrates deployment
- Waits for controllers
- Performs health checks
- Verifies platform readiness

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$(dirname "$SCRIPT_DIR")"

cd "$TERRAFORM_DIR"

source "$SCRIPT_DIR/common.sh"

echo "Working directory: $(pwd)"

ls

set -euo pipefail

trap 'echo ""; echo "ERROR: Deployment failed on line $LINENO"; exit 1' ERR

# --------------------------------------------------------------------
# Deployment Configuration
#
# Purpose:
# Centralise values that may change between environments.
# --------------------------------------------------------------------

AWS_REGION="eu-west-2"
CLUSTER_NAME="jenkins-eks"
NAMESPACE="jenkins"

# --------------------------------------------------------------------
# Prerequisite Checks
#
# Purpose:
# Verify all required tools are installed before deployment begins.
# --------------------------------------------------------------------

command -v terraform >/dev/null || { echo "ERROR: Terraform is not installed."; exit 1; }
command -v aws >/dev/null || { echo "ERROR: AWS CLI is not installed."; exit 1; }
command -v kubectl >/dev/null || { echo "ERROR: kubectl is not installed."; exit 1; }
command -v helm >/dev/null || { echo "ERROR: Helm is not installed."; exit 1; }

echo "✓ All prerequisites found."

# --------------------------------------------------------------------
# AWS Authentication Check
#
# Purpose:
# Verify AWS credentials are valid before provisioning infrastructure.
# --------------------------------------------------------------------

echo "Verifying AWS credentials..."

aws sts get-caller-identity

echo "✓ AWS credentials verified."

print_banner "Starting Jenkins EKS Deployment"

# --------------------------------------------------------------------
# Terraform Validation
#
# Purpose:
# Ensure Terraform configuration is correctly formatted and valid
# before planning or applying infrastructure changes.
# --------------------------------------------------------------------

print_banner "Terraform Validation"

echo "Formatting Terraform configuration..."

terraform fmt -recursive

echo "✓ Terraform formatting complete."

echo "Validating Terraform configuration..."

terraform validate

echo "✓ Terraform validation complete. "

print_banner "Preparing Kubernetes"

#
# Purpose:
# Refresh the local kubeconfig if an EKS cluster already exists.
# This ensures Terraform and kubectl communicate with the current
# Kubernetes API endpoint.
#

echo "Checking for an existing EKS cluster..."

if aws eks describe-cluster \
    --region "$AWS_REGION" \
    --name "$CLUSTER_NAME" >/dev/null 2>&1; then

    echo "Existing cluster found. Updating kubeconfig..."

    aws eks update-kubeconfig \
        --region "$AWS_REGION" \
        --name "$CLUSTER_NAME"

    echo "✓ kubeconfig updated"

else

    echo "No existing cluster found. Terraform will create one."

fi

# --------------------------------------------------------------------
# Terraform Plan & Apply
#
# Purpose:
# Create a deployment plan, allow it to be reviewed,
# then apply the exact approved plan.
# --------------------------------------------------------------------

print_banner "Terraform Deployment"

echo "Creating Terraform execution plan..."

terraform plan -out=tfplan

echo "✓ Terraform plan created."

echo "Applying Terraform plan..."

terraform apply -auto-approve tfplan

echo "✓ Terraform apply complete."

#
# Purpose:
# Update the local kubeconfig so kubectl points to the
# EKS cluster created by Terraform.
#

print_banner "Configuring Kubernetes"

aws eks update-kubeconfig \
  --region "$AWS_REGION" \
  --name "$CLUSTER_NAME"

  kubectl cluster-info > /dev/null

echo "✓ Connected to Kubernetes cluster"

kubectl get nodes

echo "✓ Cluster connectivity verified."

echo ""
echo "Verifying AWS Load Balancer Controller..."

kubectl wait \
  --for=condition=Available \
  deployment/aws-load-balancer-controller \
  -n kube-system \
  --timeout=120s

echo "✓ AWS Load Balancer Controller is ready."

echo ""
echo "Verifying Amazon EBS CSI Driver..."

kubectl wait \
  --for=condition=Available \
  deployment/ebs-csi-controller \
  -n kube-system \
  --timeout=120s

echo "✓ Amazon EBS CSI Driver is ready."

# --------------------------------------------------------------------
# Snapshot Infrastructure
#
# Purpose:
# Install the Kubernetes Volume Snapshot CRDs, Snapshot Controller,
# and VolumeSnapshotClass required for EBS snapshots.
# --------------------------------------------------------------------

print_banner "Installing Snapshot Infrastructure"

bash k8s/snapshot/install.sh

echo "✓ Snapshot infrastructure installed."

# ------------------------------------------------------------
# Storage Resources
#
# Purpose:
# Verify the Kubernetes StorageClasses created by Terraform.
# ------------------------------------------------------------

print_banner "Verifying Storage"

echo "Current StorageClasses:"

kubectl get storageclass

echo "✓ Storage resources verified."

# ------------------------------------------------------------
# Kubernetes Workloads
#
# Purpose:
# Deploy Kubernetes application workloads that are not yet
# managed by Terraform.
# ------------------------------------------------------------

print_banner "Verifying Kubernetes Workloads"

#
# Purpose:
# Wait for the Terraform-managed Kubernetes resources
# to become ready before continuing.
#

echo ""
echo "Waiting for the Jenkins pod to become Ready..."
echo "This can take several minutes while the image is downloaded and started."
echo "Please do not close the terminal or press Ctrl+C."
echo ""

kubectl wait \
    --for=condition=ready pod \
    -l app=jenkins \
    -n "$NAMESPACE" \
    --timeout=300s

echo "✓ Jenkins pod is ready"

sleep 10

kubectl wait \
    --for=jsonpath='{.status.phase}'=Bound \
    pvc/jenkins-pvc \
    -n "$NAMESPACE" \
    --timeout=120s

echo "✓ PVC is successfully bound"

kubectl get pods -n "$NAMESPACE"

echo "✓ Pod status verified"

kubectl get pvc -n "$NAMESPACE"

echo "✓ PVC status verified"

kubectl get svc -n "$NAMESPACE"

echo "✓ Service status verified"

print_banner "Verifying Ingress"

echo "✓ Waiting for Ingress to be be assigned a hostname..."

kubectl wait \
  --for=jsonpath='{.status.loadBalancer.ingress[0].hostname}' \
  ingress/jenkins-ingress \
  -n "$NAMESPACE" \
  --timeout=300s

echo "✓ Ingress hostname assigned"

echo ""
echo "Ingress status:"
kubectl get ingress -n "$NAMESPACE"

echo ""
echo "Service status:"
kubectl get svc -n "$NAMESPACE"

echo ""
echo "Cleaning temporary Terraform files..."

rm -f tfplan

echo "✓ Temporary Terraform files removed."
echo ""

print_banner "Deployment Complete!"

print_banner "Deployment Verification"

echo ""
echo "Nodes:"
kubectl get nodes

echo ""
echo "Storage Classes:"
kubectl get storageclass

echo ""
echo "Volume Snapshot Classes:"
kubectl get volumesnapshotclass

echo ""
echo "Snapshot Controller:"
kubectl get deployment snapshot-controller -n kube-system

echo ""
echo "EBS CSI Controller:"
kubectl get deployment ebs-csi-controller -n kube-system

echo ""
echo "Jenkins:"
kubectl get all -n jenkins

echo ""
echo "Ingress:"
kubectl get ingress -n jenkins

echo ""
echo "PVC:"
kubectl get pvc -n jenkins

echo ""
echo "PV:"
kubectl get pv

echo ""
echo "✓ Deployment verification complete."