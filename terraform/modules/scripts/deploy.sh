#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_ROOT/terraform"

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
# Helper Functions
#
# Purpose:
# Reusable functions used throughout the deployment.
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

terraform apply tfplan

echo "✓ Terraform apply complete."

print_banner "Configuring Kubernetes"

aws eks update-kubeconfig \
  --region "$AWS_REGION" \
  --name "$CLUSTER_NAME"

echo "✓ Kubeconfig updated."

kubectl get nodes

echo "✓ Cluster connectivity verified."

kubectl get storageclass

echo "✓ StorageClass verified."

print_banner "Deploying Jenkins"

kubectl create namespace "$NAMESPACE" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "✓ Namespace created."

kubectl apply -f /jenkins-pvc.yaml

echo "✓ PVC created"

kubectl apply -f k8s/jenkins-deployment.yaml

echo "✓ Deployment created"

kubectl apply -f k8s/jenkins-service.yaml

echo "✓ Service created"

echo ""
echo "Waiting for the Jenkins pod to become Ready..."
echo "This can take several minutes while the image is downloaded and started."
echo "Please do not close the terminal or press Ctrl+C, the deployment will continue automatically once the pod is Ready."
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

print_banner "Creating Ingress"

kubectl apply -f k8s/jenkins-ingress.yaml

echo "✓ Waiting for Ingress to be created and assigned a hostname..."

kubectl wait \
  --for=jsonpath='{.status.loadBalancer.ingress[0].hostname}' \
  ingress/jenkins-ingress \
  -n "$NAMESPACE" \
  --timeout=300s

echo "✓ Ingress created and hostname assigned"

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