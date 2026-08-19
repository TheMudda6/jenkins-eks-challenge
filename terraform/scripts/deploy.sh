#!/bin/bash

set -euo pipefail

cleanup() {
    rm -f tfplan
}

trap cleanup EXIT
trap 'echo ""; echo "ERROR: Deployment failed on line $LINENO"; exit 1' ERR

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$(dirname "$SCRIPT_DIR")"
REPO_ROOT="$(dirname "$TERRAFORM_DIR")"

cd "$TERRAFORM_DIR"

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

echo "Building Docker image..."

docker build \
    -t application:latest \
    -f application/Dockerfile \
    application

echo "✓ Docker image built successfully."

# --------------------------------------------------------------------
# Docker Tag
#
# Purpose:
# Tag the locally built Docker image for Amazon ECR.
# --------------------------------------------------------------------

echo
echo "Tagging Docker image..."

docker tag \
    application:latest \
    "${REPOSITORY_URL}:latest"

echo "✓ Docker image tagged."

# --------------------------------------------------------------------
# Docker Push
#
# Purpose:
# Upload the application image to Amazon ECR so Kubernetes can pull it.
# --------------------------------------------------------------------

echo
echo "Pushing Docker image to Amazon ECR..."

docker push \
    "${REPOSITORY_URL}:latest"

echo "✓ Docker image pushed successfully."

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
echo "Applying ArgoCD root Application..."

kubectl apply \
  -f "$REPO_ROOT/kubernetes/applications/argocd-application.yaml"

echo "✓ ArgoCD root Application applied."

echo "✓ Cluster connectivity verified."

echo
echo "Verifying AWS Load Balancer Controller..."

kubectl wait \
  --for=condition=Available \
  deployment/aws-load-balancer-controller \
  -n kube-system \
  --timeout=120s

echo "✓ AWS Load Balancer Controller is ready."

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

bash k8s/snapshot/install.sh

echo "✓ Snapshot infrastructure installed."

# --------------------------------------------------------------------
# Storage Resources
# --------------------------------------------------------------------

print_banner "Storage Resources"

echo "Creating gp3 StorageClass..."

kubectl apply -f k8s/storage/gp3-storageclass.yaml

echo "✓ gp3 StorageClass created."

echo "Creating gp3-retain StorageClass..."

kubectl apply -f k8s/storage/gp3-retain-storageclass.yaml

echo "✓ gp3-retain StorageClass created."

echo
echo "Current StorageClasses:"

kubectl get storageclass

echo "✓ Storage resources verified."

# --------------------------------------------------------------------
# PostgreSQL Deployment
# --------------------------------------------------------------------

# --------------------------------------------------------------------
# PostgreSQL Secret
#
# Purpose:
# Generate the PostgreSQL Secret from the local template and apply it
# to the Kubernetes cluster.
# --------------------------------------------------------------------

print_banner "Generating PostgreSQL Secret"

set -a
source .env
set +a

envsubst \
    < k8s/postgres/postgres-secret.yaml.template \
    > k8s/postgres/postgres-secret.yaml

if [ ! -f k8s/postgres/postgres-secret.yaml ]; then
    echo "ERROR: Failed to generate PostgreSQL Secret."
    exit 1
fi

echo "✓ PostgreSQL Secret generated."

kubectl apply \
    -f k8s/postgres/postgres-secret.yaml

echo "✓ PostgreSQL Secret applied."

kubectl get secret postgres-secret \
    -n "$NAMESPACE"

echo "✓ PostgreSQL Secret verified."

print_banner "Deploying PostgreSQL"

echo "Creating PostgreSQL Headless Service..."

kubectl apply -f k8s/postgres/postgres-service.yaml

echo "✓ PostgreSQL Service created."

echo "Creating PostgreSQL StatefulSet..."

kubectl apply -f k8s/postgres/postgres-statefulset.yaml

echo "✓ PostgreSQL StatefulSet created."

echo
echo "Waiting for PostgreSQL StatefulSet rollout..."

kubectl rollout status \
    statefulset/postgres \
    -n "$NAMESPACE" \
    --timeout=300s

echo "✓ PostgreSQL StatefulSet rollout complete."

echo
echo "Waiting for PostgreSQL Pod..."

kubectl wait \
    --for=condition=Ready \
    pod/postgres-0 \
    -n "$NAMESPACE" \
    --timeout=300s

echo "✓ PostgreSQL Pod is ready."

echo
echo "Waiting for PostgreSQL PVC..."

kubectl wait \
  --for=jsonpath='{.status.phase}'=Bound \
  pvc/postgres-data-postgres-0 \
  -n "$NAMESPACE" \
  --timeout=120s

echo "✓ PostgreSQL PVC is bound."

echo
echo "PostgreSQL resources:"

echo
echo "PostgreSQL Pods:"
kubectl get pods -l app=postgres -n "$NAMESPACE"

echo
echo "PostgreSQL Service:"
kubectl get svc postgres -n "$NAMESPACE"

echo
echo "PostgreSQL PVC:"
kubectl get pvc -n "$NAMESPACE"

echo
echo "PostgreSQL Endpoints:"
kubectl get endpoints postgres -n "$NAMESPACE"

echo
echo "PostgreSQL StatefulSet:"
kubectl get statefulset postgres -n "$NAMESPACE"

echo "✓ PostgreSQL verification complete."

# --------------------------------------------------------------------
# Redis Deployment
# --------------------------------------------------------------------

print_banner "Deploying Redis"

echo "Creating Redis Service..."

kubectl apply -f k8s/redis/redis-service.yaml

echo "✓ Redis Service created."

echo "Creating Redis Deployment..."

kubectl apply -f k8s/redis/redis-deployment.yaml

echo "✓ Redis Deployment created."

echo
echo "Waiting for Redis Deployment rollout..."

kubectl rollout status \
    deployment/redis \
    -n "$NAMESPACE" \
    --timeout=300s

echo "✓ Redis Deployment rollout complete."

echo
echo "Waiting for Redis Pod..."

kubectl wait \
    --for=condition=Ready \
    pod \
    -l app=redis \
    -n "$NAMESPACE" \
    --timeout=300s

echo "✓ Redis Pod is ready."

echo
echo "Redis resources:"

echo
echo "Redis Pods:"
kubectl get pods -l app=redis -n "$NAMESPACE"

echo
echo "Redis Service:"
kubectl get svc redis -n "$NAMESPACE"

echo
echo "Redis Endpoints:"
kubectl get endpoints redis -n "$NAMESPACE"

echo
echo "✓ Redis verification complete."

# --------------------------------------------------------------------
# Application Deployment
# --------------------------------------------------------------------

print_banner "Deploying Application"

echo "Creating Application Service Account..."

kubectl apply -f k8s/application/application-serviceaccount.yaml

echo "✓ Application Service Account created."

echo "Creating Application Deployment..."

kubectl apply -f k8s/application/application-deployment.yaml

echo "✓ Application Deployment created."

echo "Creating Application Service..."

kubectl apply -f k8s/application/application-service.yaml

echo "✓ Application Service created."

echo
echo "Waiting for Application deployment rollout..."

kubectl rollout status \
    deployment/application \
    -n "$NAMESPACE" \
    --timeout=300s

echo "✓ Application Deployment rollout complete."

echo
echo "Waiting for Application Pod..."

kubectl wait \
    --for=condition=Ready \
    pod \
    -l app=application \
    -n "$NAMESPACE" \
    --timeout=300s

echo "✓ Application Pod is ready."

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
echo "✓ Application verification complete."

# --------------------------------------------------------------------
# Jenkins Deployment
# --------------------------------------------------------------------

print_banner "Deploying Jenkins"

kubectl apply -f k8s/jenkins/jenkins-pvc.yaml
echo "✓ PVC created"

kubectl apply -f k8s/jenkins/jenkins-deployment.yaml
echo "✓ Deployment created"

kubectl apply -f k8s/jenkins/jenkins-service.yaml
echo "✓ Service created"

echo
echo "Waiting for Jenkins deployment rollout..."

kubectl rollout status deployment/jenkins \
  -n "$NAMESPACE" \
  --timeout=300s

echo "✓ Deployment rollout complete"

echo
echo "Waiting for the Jenkins pod to become Ready..."
echo "This can take several minutes while the image is downloaded and started."

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

kubectl get endpoints -n "$NAMESPACE"
echo "✓ Service endpoints verified"

# --------------------------------------------------------------------
# Ingress
# --------------------------------------------------------------------

print_banner "Creating Ingress"

kubectl apply -f k8s/jenkins/jenkins-ingress.yaml

echo "✓ Waiting for Ingress to be created and assigned a hostname..."

kubectl wait \
  --for=jsonpath='{.status.loadBalancer.ingress[0].hostname}' \
  ingress/jenkins-ingress \
  -n "$NAMESPACE" \
  --timeout=300s

echo "✓ Ingress created and hostname assigned"

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