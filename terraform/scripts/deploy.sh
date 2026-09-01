#!/bin/bash

set -euo pipefail

cleanup() {
    rm -f tfplan dns.tfplan
}

trap cleanup EXIT
trap 'echo ""; echo "ERROR: Deployment failed on line $LINENO"; exit 1' ERR

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$(dirname "$SCRIPT_DIR")"
REPO_ROOT="$(dirname "$TERRAFORM_DIR")"

cd "$TERRAFORM_DIR"

# --------------------------------------------------------------------
# Environment Variables
#
# Purpose:
# Load local environment variables required by Terraform providers.
# --------------------------------------------------------------------

ENV_FILE="$TERRAFORM_DIR/.env"

if [ -f "$ENV_FILE" ]; then
    set -a
    source "$ENV_FILE"
    set +a
fi

if [ -z "${TF_VAR_cloudflare_api_token:-}" ]; then
    echo "ERROR: TF_VAR_cloudflare_api_token is not set."
    echo "Check $ENV_FILE"
    exit 1
fi

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

command -v docker >/dev/null || {
    echo "ERROR: Docker is not installed."
    exit 1
}

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

echo "✓ Terraform validation complete."

# --------------------------------------------------------------------
# Terraform Plan & Apply
#
# Purpose:
# Create a deployment plan, review it,
# then apply the exact approved plan.
# --------------------------------------------------------------------

print_banner "Terraform Deployment"

echo "Creating Terraform execution plan..."

echo "Checking Terraform Cloudflare token availability..."

if [ -n "${TF_VAR_cloudflare_api_token:-}" ]; then
    echo "✓ Terraform Cloudflare token available."
else
    echo "ERROR: Terraform Cloudflare token missing."
    exit 1
fi

terraform plan -out=tfplan

echo "✓ Terraform plan created."

echo "Applying Terraform plan..."

terraform apply tfplan

echo "✓ Terraform apply complete."

echo
echo "Retrieving Terraform outputs..."

QUEUE_URL=$(terraform output -raw queue_url)

if [ -z "$QUEUE_URL" ]; then
    echo "ERROR: Failed to retrieve Queue URL."
    exit 1
fi

echo "✓ Queue URL retrieved."

QUEUE_ARN=$(terraform output -raw queue_arn)

if [ -z "$QUEUE_ARN" ]; then
    echo "ERROR: Failed to retrieve Queue ARN."
    exit 1
fi

echo "✓ Queue ARN retrieved."

QUEUE_NAME=$(terraform output -raw queue_name)

if [ -z "$QUEUE_NAME" ]; then
    echo "ERROR: Failed to retrieve Queue Name."
    exit 1
fi

echo "✓ Queue name retrieved."

REPOSITORY_URL=$(terraform output -raw repository_url)

if [ -z "$REPOSITORY_URL" ]; then
    echo "ERROR: Failed to retrieve ECR Repository URL."
    exit 1
fi

echo "✓ Repository URL retrieved."

REPOSITORY_NAME=$(terraform output -raw repository_name)

if [ -z "$REPOSITORY_NAME" ]; then
    echo "ERROR: Failed to retrieve ECR Repository Name."
    exit 1
fi

echo "✓ Repository name retrieved."

REGISTRY_URL="${REPOSITORY_URL%%/*}"

if [ -z "$REGISTRY_URL" ]; then
    echo "ERROR: Failed to determine ECR registry URL."
    exit 1
fi

echo "✓ ECR registry URL determined."

# --------------------------------------------------------------------
# Docker Authentication
#
# Purpose:
# Authenticate Docker with Amazon ECR.
# --------------------------------------------------------------------

print_banner "Docker Authentication"

echo "Logging into Amazon ECR..."

aws ecr get-login-password \
| docker login \
    --username AWS \
    --password-stdin "$REGISTRY_URL"

echo "✓ Docker authenticated with Amazon ECR."

# --------------------------------------------------------------------
# Docker Build
#
# Purpose:
# Build the Go application container image.
# --------------------------------------------------------------------

print_banner "Building Application Image"

echo "Changing to repository root..."

cd "$REPO_ROOT"

echo "✓ Repository root located."

echo "Returning to Terraform directory..."

cd "$TERRAFORM_DIR"

echo "✓ Returned to Terraform directory."

# --------------------------------------------------------------------
# Kubernetes Configuration
# --------------------------------------------------------------------

print_banner "Configuring Kubernetes"

aws eks update-kubeconfig \
  --region "$AWS_REGION" \
  --name "$CLUSTER_NAME"

kubectl get nodes

echo
echo "Waiting for ArgoCD..."

kubectl wait \
--for=condition=Available \
deployment/argocd-server \
-n argocd \
--timeout=300s

echo "✓ ArgoCD is ready."

echo
echo "✓ Cluster connectivity verified."

# --------------------------------------------------------------------
#
# Karpenter
#
# Purpose:
# Verify that the Karpenter controller is running before applying the
# EC2NodeClass and NodePool resources that define dynamic node capacity.
#
# The Karpenter controller must be available first because it is
# responsible for reconciling the NodePool and provisioning EC2 nodes.
#
# --------------------------------------------------------------------

print_banner "Configuring Karpenter"

echo "Waiting for Karpenter controller..."

kubectl wait \
  --for=condition=Available \
  deployment/karpenter \
  -n kube-system \
  --timeout=300s

echo "✓ Karpenter controller is ready."

echo
echo "Applying Karpenter EC2NodeClass..."

kubectl apply \
  -f "$TERRAFORM_DIR/modules/karpenter/ec2_node_class.yaml"

echo "✓ Karpenter EC2NodeClass applied."

echo
echo "Applying Karpenter NodePool..."

kubectl apply \
  -f "$TERRAFORM_DIR/modules/karpenter/node_pool.yaml"

echo "✓ Karpenter NodePool applied."

echo
echo "Verifying Karpenter resources..."

kubectl get ec2nodeclass default
kubectl get nodepool default

echo "✓ Karpenter resources verified."

echo
echo "Verifying AWS Load Balancer Controller..."

kubectl wait \
  --for=condition=Available \
  deployment/aws-load-balancer-controller \
  -n kube-system \
  --timeout=120s

echo "✓ AWS Load Balancer Controller is ready."

echo
echo "Waiting for AWS Load Balancer webhook endpoint..."

ALB_WEBHOOK_TIMEOUT=300
ALB_WEBHOOK_ELAPSED=0

until kubectl get endpoints \
aws-load-balancer-webhook-service \
-n kube-system \
-o jsonpath='{.subsets[*].addresses[*].ip}' | grep -q .; do

    if [ "$ALB_WEBHOOK_ELAPSED" -ge "$ALB_WEBHOOK_TIMEOUT" ]; then
        echo "ERROR: AWS Load Balancer webhook did not become ready."
        exit 1
    fi

    echo "Waiting for AWS Load Balancer webhook..."
    sleep 10
    ALB_WEBHOOK_ELAPSED=$((ALB_WEBHOOK_ELAPSED + 10))

done

echo "✓ AWS Load Balancer webhook is ready."

echo
echo "Verifying Amazon EBS CSI Driver..."

kubectl wait \
  --for=condition=Available \
  deployment/ebs-csi-controller \
  -n kube-system \
  --timeout=120s

echo "✓ Amazon EBS CSI Driver is ready."

# --------------------------------------------------------------------
# Kubernetes Namespace
#
# Purpose:
# Create the namespace used by all application workloads.
# --------------------------------------------------------------------

print_banner "Creating Kubernetes Namespace"

kubectl create namespace "$NAMESPACE" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "✓ Namespace created."

# --------------------------------------------------------------------
# Snapshot Infrastructure
# --------------------------------------------------------------------

print_banner "Installing Snapshot Infrastructure"

bash infrastructure/snapshot/install.sh

echo "✓ Snapshot infrastructure installed."

# --------------------------------------------------------------------
# Storage Resources
# --------------------------------------------------------------------

print_banner "Storage Resources"

echo "Creating gp3 StorageClass..."

kubectl apply -f infrastructure/storage/gp3-storageclass.yaml

echo "✓ gp3 StorageClass created."

echo "Creating gp3-retain StorageClass..."

kubectl apply -f infrastructure/storage/gp3-retain-storageclass.yaml

echo "✓ gp3-retain StorageClass created."

echo
echo "Current StorageClasses:"

kubectl get storageclass

echo "✓ Storage resources verified."

# --------------------------------------------------------------------
# External Secrets
#
# Purpose:
# Configure Kubernetes secret synchronization from AWS Secrets Manager.
#
# Note:
# External Secrets Operator v2.x uses external-secrets.io/v1 API versions.
# Manifests must match the installed CRD version.
# --------------------------------------------------------------------

print_banner "Installing External Secrets Operator"

helm repo add external-secrets https://charts.external-secrets.io || true

helm repo update

helm upgrade --install external-secrets \
  external-secrets/external-secrets \
  --namespace external-secrets \
  --create-namespace \
  --set installCRDs=true

echo "Waiting for External Secrets Operator..."

kubectl wait \
  --for=condition=Available \
  deployment/external-secrets \
  -n external-secrets \
  --timeout=300s

echo "✓ External Secrets Operator ready."


# --------------------------------------------------------------------
# External Secrets CRD Verification
#
# Purpose:
# Ensure Kubernetes has registered External Secrets resources
# before applying ClusterSecretStore and ExternalSecret objects.
# --------------------------------------------------------------------

echo
echo "Waiting for External Secrets CRDs..."

kubectl wait \
  --for=condition=Established \
  crd/externalsecrets.external-secrets.io \
  --timeout=120s

kubectl wait \
  --for=condition=Established \
  crd/clustersecretstores.external-secrets.io \
  --timeout=120s

echo "✓ External Secrets CRDs registered."

echo
echo "Refreshing Kubernetes API discovery..."

kubectl api-resources >/dev/null

echo "Refreshing Kubernetes API discovery complete."

echo "Checking External Secrets API availability..."

kubectl api-resources | grep external-secrets.io

echo "✓ External Secrets API registered."

echo "Verifying External Secrets resources..."

if kubectl get crd externalsecrets.external-secrets.io >/dev/null 2>&1; then
    echo "✓ ExternalSecret CRD available."
else
    echo "ERROR: ExternalSecret CRD not available."
    exit 1
fi

if kubectl get crd clustersecretstores.external-secrets.io >/dev/null 2>&1; then
    echo "✓ ClusterSecretStore CRD available."
else
    echo "ERROR: ClusterSecretStore CRD not available."
    exit 1
fi

print_banner "Deploying External Secrets Configuration"

echo "Applying External Secrets resources..."

kubectl apply -k infrastructure/secrets

echo "✓ External Secrets resources applied."

echo
echo "Waiting for PostgreSQL secret synchronization..."

kubectl wait \
  --for=condition=Ready \
  externalsecret/postgres-secret \
  -n "$NAMESPACE" \
  --timeout=120s

echo "✓ PostgreSQL secret synchronized."

kubectl describe secret postgres-secret \
  -n "$NAMESPACE"

echo "✓ PostgreSQL Secret verified."

echo "✓ Cloudflare DNS configured."

# --------------------------------------------------------------------
# ArgoCD Application Deployment
#
# Purpose:
# Create the ArgoCD Application after cluster prerequisites exist.
# ArgoCD will manage application lifecycle from Git.
# --------------------------------------------------------------------

print_banner "Installing ArgoCD Application"

helm upgrade --install jenkins-application \
  "$TERRAFORM_DIR/modules/argocd/jenkins-application" \
  -n argocd \
  --create-namespace \
  --wait \
  --timeout 5m

echo "✓ Jenkins ArgoCD Application installed."

echo
echo "Waiting for Jenkins ArgoCD Application sync..."

ARGOCD_TIMEOUT=300
ARGOCD_ELAPSED=0

until kubectl get application jenkins-application \
-n argocd \
-o jsonpath='{.status.sync.status} {.status.health.status}' | grep -q "Synced Healthy"; do

    if [ "$ARGOCD_ELAPSED" -ge "$ARGOCD_TIMEOUT" ]; then
        echo "ERROR: Jenkins ArgoCD Application did not sync."
        kubectl get application jenkins-application -n argocd
        exit 1
    fi

    echo "Waiting for ArgoCD sync..."
    sleep 10
    ARGOCD_ELAPSED=$((ARGOCD_ELAPSED + 10))

done

echo "✓ Jenkins ArgoCD Application synced."

# --------------------------------------------------------------------
# Cloudflare DNS
#
# Purpose:
# Retrieve the AWS Load Balancer hostname assigned to the Ingress.
# --------------------------------------------------------------------

echo
echo "Retrieving ALB hostname..."

ALB_HOSTNAME=$(kubectl get ingress jenkins-ingress \
    -n "$NAMESPACE" \
    -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
    
if [ -z "$ALB_HOSTNAME" ]; then
    echo
    echo "ERROR: Failed to retrieve the ALB hostname."
    exit 1
fi

echo "✓ ALB Hostname:"
echo "$ALB_HOSTNAME"

echo
echo "Verifying ALB DNS..."

if nslookup "$ALB_HOSTNAME" >/dev/null 2>&1; then
    echo "✓ ALB hostname resolves."
else
    echo "WARNING: ALB hostname is not yet resolvable."
    echo "DNS propagation may still be in progress."
fi

echo
echo "Ingress status:"
kubectl get ingress -n "$NAMESPACE"

echo
echo "Ingress details:"
kubectl describe ingress jenkins-ingress -n "$NAMESPACE"

# --------------------------------------------------------------------
# Cloudflare DNS Configuration
# --------------------------------------------------------------------

print_banner "Configuring Cloudflare DNS"

echo "Creating Terraform plan for Cloudflare DNS..."

terraform -chdir="$TERRAFORM_DIR/dns" plan \
    -var="cloudflare_zone_name=mud-as-sir.uk" \
    -var="jenkins_hostname=jenkins.mud-as-sir.uk" \
    -var="alb_hostname=$ALB_HOSTNAME" \
    -out=dns.tfplan

echo "✓ Cloudflare DNS plan created."

echo "Applying Cloudflare DNS plan..."

terraform -chdir="$TERRAFORM_DIR/dns" apply dns.tfplan

echo "✓ Cloudflare DNS configured."

echo
echo "ArgoCD Application status:"

kubectl get application \
jenkins-application \
-n argocd

echo

echo "Waiting for application workloads to become available..."

kubectl wait \
--for=condition=Available \
deployment/application \
-n "$NAMESPACE" \
--timeout=300s

echo "✓ Application deployment available."

kubectl wait \
--for=condition=Available \
deployment/jenkins \
-n "$NAMESPACE" \
--timeout=300s

echo "✓ Jenkins deployment available."

# --------------------------------------------------------------------
# Deployment Verification
# --------------------------------------------------------------------

print_banner "Deployment Verification"

echo
echo "Nodes:"
kubectl get nodes

echo
echo "Storage Classes:"
kubectl get storageclass

echo
echo "Volume Snapshot Classes:"
kubectl get volumesnapshotclass

echo
echo "Snapshot Controller:"
kubectl get deployment snapshot-controller -n kube-system

echo
echo "EBS CSI Controller:"
kubectl get deployment ebs-csi-controller -n kube-system

echo
echo "PostgreSQL StatefulSet:"
kubectl get statefulset postgres -n "$NAMESPACE"

echo
echo "PostgreSQL Pods:"
kubectl get pods -l app=postgres -n "$NAMESPACE"

echo
echo "PostgreSQL Service:"
kubectl get svc postgres -n "$NAMESPACE"

echo
echo "PostgreSQL PVC:"
kubectl get pvc -l app=postgres -n "$NAMESPACE"

echo
echo "Redis Deployment:"
kubectl get deployment redis -n "$NAMESPACE"

echo
echo "Redis Pods:"
kubectl get pods -l app=redis -n "$NAMESPACE"

echo
echo "Redis Service:"
kubectl get svc redis -n "$NAMESPACE"

echo
echo "Application Deployment:"
kubectl get deployment application -n "$NAMESPACE"

echo
echo "Application Pods:"
kubectl get pods -l app=application -n "$NAMESPACE"

echo
echo "Application Service:"
kubectl get svc application -n "$NAMESPACE"

echo
echo "Application Endpoints:"
kubectl get endpoints application -n "$NAMESPACE"

echo
echo "Jenkins Deployment:"
kubectl get deployment jenkins -n "$NAMESPACE"

echo
echo "Jenkins Pods:"
kubectl get pods -l app=jenkins -n "$NAMESPACE"

echo
echo "Ingress:"
kubectl get ingress -n "$NAMESPACE"

echo
echo "PVC:"
kubectl get pvc -n "$NAMESPACE"

echo
echo "PV:"
kubectl get pv

echo
echo "✓ Deployment verification complete."

print_banner "Deployment Successful"

echo "Jenkins Platform has been deployed successfully."
echo
echo "Public URL:"
echo "https://jenkins.mud-as-sir.uk"
echo
echo "Run ./destroy.sh when finished to minimise AWS costs."