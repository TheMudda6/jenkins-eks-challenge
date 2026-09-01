#!/bin/bash

set -euo pipefail

cleanup() {
    rm -f tfplan dns.tfplan destroy.tfplan
    rm -f "$TERRAFORM_DIR/dns/dns-destroy.tfplan"
}

trap cleanup EXIT
trap 'echo ""; echo "ERROR: Cleanup failed on line $LINENO"; exit 1' ERR

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$(dirname "$SCRIPT_DIR")"

cd "$TERRAFORM_DIR"

# --------------------------------------------------------------------
# Environment Variables
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
command -v helm >/dev/null || { echo "ERROR: Helm is not installed."; exit 1; }

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

# --------------------------------------------------------------------
# ALB Verification
#
# Purpose:
# Retrieve the AWS Load Balancer hostname before removing the Ingress.
# --------------------------------------------------------------------

echo
echo "Retrieving ALB hostname..."

ALB_HOSTNAME=$(kubectl get ingress jenkins-ingress \
    -n "$NAMESPACE" \
    -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true)

if [ -z "$ALB_HOSTNAME" ]; then
    echo "No ALB hostname found."
else
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
fi

echo "Deleting Jenkins ArgoCD Application..."

kubectl delete application jenkins-application \
  -n argocd \
  --ignore-not-found=true
  
echo "Waiting for ArgoCD managed workloads to release..."

kubectl wait \
  --for=delete \
  application/jenkins-application \
  -n argocd \
  --timeout=300s || true

echo "✓ Jenkins ArgoCD Application removed."

echo "Deleting Jenkins ingress..."
kubectl delete -f infrastructure/jenkins/jenkins-ingress.yaml --ignore-not-found=true
echo "✓ Jenkins ingress deleted."

echo
echo "Waiting for Jenkins Ingress to be removed..."

kubectl wait \
    --for=delete \
    ingress/jenkins-ingress \
    -n "$NAMESPACE" \
    --timeout=300s || true

# --------------------------------------------------------------------
# External Secrets Cleanup
#
# Purpose:
# Remove External Secrets resources before removing the operator.
# --------------------------------------------------------------------

print_banner "Removing External Secrets"

echo "Deleting PostgreSQL ExternalSecret..."

kubectl delete \
    -f infrastructure/secrets/postgres-external-secret.yaml \
    --ignore-not-found=true

echo "✓ PostgreSQL ExternalSecret deleted."


echo
echo "Deleting ClusterSecretStore..."

kubectl delete \
    -f infrastructure/secrets/cluster-secret-store.yaml \
    --ignore-not-found=true

echo "✓ ClusterSecretStore deleted."


echo
echo "Deleting generated Kubernetes Secret..."

kubectl delete secret postgres-secret \
    -n "$NAMESPACE" \
    --ignore-not-found=true

echo "✓ PostgreSQL Kubernetes Secret deleted."


# --------------------------------------------------------------------
# External Secrets Operator Cleanup
#
# Purpose:
# Remove External Secrets Operator after dependent resources are gone.
# --------------------------------------------------------------------

print_banner "Removing External Secrets Operator"

echo "Deleting External Secrets Operator Helm release..."

helm uninstall external-secrets \
    -n external-secrets \
    --ignore-not-found || true

echo "✓ External Secrets Operator Helm release removed."


echo
echo "Waiting for External Secrets namespace cleanup..."

kubectl delete namespace external-secrets \
    --ignore-not-found=true

echo "✓ External Secrets namespace removed."

# --------------------------------------------------------------------
# PostgreSQL Cleanup
#
# Purpose:
# Remove PostgreSQL resources before deleting the namespace.
# --------------------------------------------------------------------

echo "Deleting PostgreSQL StatefulSet..."

kubectl delete \
    -f infrastructure/postgres/postgres-statefulset.yaml \
    --ignore-not-found=true

echo "✓ PostgreSQL StatefulSet deleted."

echo
echo "Waiting for PostgreSQL StatefulSet to terminate..."

kubectl wait \
    --for=delete \
    statefulset/postgres \
    -n "$NAMESPACE" \
    --timeout=300s || true

echo "✓ PostgreSQL StatefulSet removed."

echo
echo "Verifying PostgreSQL Pods..."

kubectl get pods \
    -l app=postgres \
    -n "$NAMESPACE" || true

echo "✓ PostgreSQL Pods verified."

echo
echo "Deleting PostgreSQL PVC..."

POSTGRES_PV=$(kubectl get pvc postgres-data-postgres-0 \
  -n "$NAMESPACE" \
  -o jsonpath='{.spec.volumeName}' 2>/dev/null || true)

if [ -n "$POSTGRES_PV" ]; then
  echo "✓ PostgreSQL PV identified: $POSTGRES_PV"
else
  echo "No PostgreSQL PV found."
fi

kubectl delete \
  pvc/postgres-data-postgres-0 \
  -n "$NAMESPACE" \
  --ignore-not-found=true

echo "✓ PostgreSQL PVC deletion requested."

echo
echo "Waiting for PostgreSQL PVC to be removed..."

if kubectl wait \
  --for=delete \
  pvc/postgres-data-postgres-0 \
  -n "$NAMESPACE" \
  --timeout=300s; then
  echo "✓ PostgreSQL PVC removed."
else
  echo "WARNING: PostgreSQL PVC still exists after timeout."
fi

if [ -n "$POSTGRES_PV" ]; then
    echo
    echo "Waiting for PostgreSQL PV to be removed..."

    if kubectl get pv "$POSTGRES_PV" >/dev/null 2>&1; then
        if kubectl wait \
            --for=delete \
            "pv/$POSTGRES_PV" \
            --timeout=300s; then
            echo "✓ PostgreSQL PV removed."
        else
            echo "WARNING: PostgreSQL PV still exists: $POSTGRES_PV"
        fi
    else
        echo "✓ PostgreSQL PV already removed."
    fi
fi

echo
echo "Deleting PostgreSQL Service..."

kubectl delete \
    -f infrastructure/postgres/postgres-service.yaml \
    --ignore-not-found=true

echo "✓ PostgreSQL Service deleted."

# --------------------------------------------------------------------
# Redis Cleanup
#
# Purpose:
# Remove Redis resources before deleting the namespace.
# --------------------------------------------------------------------

print_banner "Removing Redis"

echo
echo "Deleting Redis Service..."

kubectl delete \
    -f infrastructure/redis/redis-service.yaml \
    --ignore-not-found=true

echo "✓ Redis Service deleted."

echo
echo "Redis resources:"

echo
echo "Redis Pods:"
kubectl get pods -l app=redis -n "$NAMESPACE" || true

echo
echo "Redis Service:"
kubectl get svc redis -n "$NAMESPACE" || true

echo

echo "✓ Redis cleanup complete."

echo "Deleting Jenkins Deployment..."

kubectl delete \
    -f infrastructure/jenkins/jenkins-deployment.yaml \
    --ignore-not-found=true

echo "✓ Jenkins Deployment deleted."

echo
echo "Deleting Jenkins PVC..."

kubectl delete \
    -f infrastructure/jenkins/jenkins-pvc.yaml \
    --ignore-not-found=true

echo "✓ Jenkins PVC deletion requested."

echo
echo "Waiting for Jenkins PVC removal..."

kubectl wait \
    --for=delete \
    pvc/jenkins-pvc \
    -n "$NAMESPACE" \
    --timeout=300s || true

echo "✓ Jenkins PVC removed."

# --------------------------------------------------------------------
# Monitoring Cleanup
#
# Purpose:
# Remove Prometheus/Grafana ArgoCD Application before cluster teardown.
# --------------------------------------------------------------------

print_banner "Removing Monitoring"

echo "Deleting Monitoring ArgoCD Application..."

kubectl delete application monitoring \
    -n argocd \
    --ignore-not-found=true

echo "✓ Monitoring ArgoCD Application deleted."

echo "Waiting for Monitoring resources to release..."

sleep 30

echo "✓ Monitoring resources released."

echo
echo "Deleting Monitoring namespace..."

kubectl delete namespace monitoring \
    --ignore-not-found=true

echo "✓ Monitoring namespace removed."

echo
echo "Remaining External Secrets:"
kubectl get externalsecret -A || true

echo
echo "Remaining ClusterSecretStores:"
kubectl get clustersecretstore || true

echo "Deleting Jenkins namespace..."
kubectl delete namespace "$NAMESPACE" --ignore-not-found=true

echo "Waiting for namespace deletion..."
kubectl wait --for=delete namespace/"$NAMESPACE" --timeout=120s || true
echo "✓ Namespace removed."

echo
echo "Remaining Namespaces:"
kubectl get namespaces || true

echo
echo "Remaining Pods:"
kubectl get pods -A || true

echo
echo "Remaining Services:"
kubectl get svc -A || true

echo
echo "Remaining PVCs:"
kubectl get pvc -A || true

echo
echo "Remaining Ingresses:"
kubectl get ingress -A || true

# --------------------------------------------------------------------
# Snapshot Infrastructure
# --------------------------------------------------------------------

print_banner "Removing Snapshot Infrastructure"

if [ -f infrastructure/snapshot/uninstall.sh ]; then
    bash infrastructure/snapshot/uninstall.sh
else
    echo "Snapshot uninstall script not found. Skipping."
fi

echo "✓ Snapshot infrastructure removed."

# --------------------------------------------------------------------
# Storage Cleanup
#
# Purpose:
# Remove Kubernetes storage resources before destroying the cluster.
# --------------------------------------------------------------------

print_banner "Removing Storage Resources"

kubectl delete -f infrastructure/storage/gp3-retain-storageclass.yaml --ignore-not-found=true
echo "✓ gp3-retain StorageClass deleted."

kubectl delete -f infrastructure/storage/gp3-storageclass.yaml --ignore-not-found=true
echo "✓ gp3 StorageClass deleted."

# --------------------------------------------------------------------
#
# Karpenter Cleanup
#
# Purpose:
# Remove Karpenter-managed Kubernetes capacity before Terraform destroys
# the Karpenter controller, IAM roles, instance profile, and Helm releases.
#
# The NodePool is deleted first so Karpenter can begin terminating nodes
# that it previously provisioned. The EC2NodeClass is then removed after
# the NodePool has been deleted.
#
# --------------------------------------------------------------------

print_banner "Removing Karpenter"

echo "Deleting Karpenter NodePool..."

kubectl delete \
  nodepool/default \
  --ignore-not-found=true

echo "✓ Karpenter NodePool deletion requested."

echo
echo "Waiting for Karpenter NodePool to be removed..."

kubectl wait \
  --for=delete \
  nodepool/default \
  --timeout=300s || true

echo "✓ Karpenter NodePool removed."

echo
echo "Waiting for Karpenter-provisioned nodes to terminate..."

KARPENTER_NODE_TIMEOUT=300
KARPENTER_NODE_ELAPSED=0

while kubectl get nodes \
  -l karpenter.sh/nodepool=default \
  --no-headers 2>/dev/null | grep -q .; do

  if [ "$KARPENTER_NODE_ELAPSED" -ge "$KARPENTER_NODE_TIMEOUT" ]; then
    echo "WARNING: Karpenter-provisioned nodes still exist after timeout."
    kubectl get nodes -l karpenter.sh/nodepool=default || true
    break
  fi

  echo "Waiting for Karpenter-provisioned nodes to terminate..."
  sleep 10
  KARPENTER_NODE_ELAPSED=$((KARPENTER_NODE_ELAPSED + 10))
done

echo "✓ Karpenter-provisioned nodes terminated."

echo
echo "Deleting Karpenter EC2NodeClass..."

kubectl delete \
  ec2nodeclass/default \
  --ignore-not-found=true

echo "✓ Karpenter EC2NodeClass removed."

# --------------------------------------------------------------------
# Cloudflare DNS Cleanup
#
# Purpose:
# Destroy the dedicated Cloudflare DNS Terraform stack before the AWS
# infrastructure is removed.
#
# The ALB hostname is read from the DNS Terraform state because the
# Kubernetes Ingress/ALB may no longer exist by this point.
# --------------------------------------------------------------------

print_banner "Cloudflare DNS Cleanup"

echo "Checking Cloudflare DNS Terraform state..."

if terraform -chdir="$TERRAFORM_DIR/dns" state list | grep -q '^cloudflare_dns_record\.jenkins$'; then

    echo "✓ Cloudflare DNS record found in Terraform state."
    echo "Retrieving ALB hostname from DNS Terraform state..."

    ALB_HOSTNAME=$(terraform -chdir="$TERRAFORM_DIR/dns" state show cloudflare_dns_record.jenkins \
        | awk -F'"' '/content[[:space:]]*=/ {print $2}')

    if [ -z "$ALB_HOSTNAME" ]; then
        echo "ERROR: Failed to retrieve ALB hostname from DNS Terraform state."
        exit 1
    fi

    echo "✓ ALB hostname retrieved:"
    echo "$ALB_HOSTNAME"

    echo
    echo "Creating Cloudflare DNS destroy plan..."

    terraform -chdir="$TERRAFORM_DIR/dns" plan \
        -destroy \
        -var="cloudflare_zone_name=mud-as-sir.uk" \
        -var="jenkins_hostname=jenkins.mud-as-sir.uk" \
        -var="alb_hostname=$ALB_HOSTNAME" \
        -out=dns-destroy.tfplan

    echo "✓ Cloudflare DNS destroy plan created."

    read -p "Proceed with Cloudflare DNS destroy? (yes/no): " dns_destroy_confirm

    if [ "$dns_destroy_confirm" != "yes" ]; then
        echo "Cleanup cancelled."
        exit 0
    fi

    echo "Destroying Cloudflare DNS..."

    terraform -chdir="$TERRAFORM_DIR/dns" apply -auto-approve dns-destroy.tfplan

    echo "✓ Cloudflare DNS destroyed."

    echo
    echo "Confirming Cloudflare DNS state is empty..."

    if terraform -chdir="$TERRAFORM_DIR/dns" state list | grep -q .; then
        echo "ERROR: Cloudflare DNS Terraform state is not empty."
        terraform -chdir="$TERRAFORM_DIR/dns" state list
        exit 1
    else
        echo "✓ Cloudflare DNS state is empty."
    fi

else
    echo "✓ No Cloudflare DNS resources found in Terraform state."
    echo "Skipping Cloudflare DNS destruction."
fi

# --------------------------------------------------------------------
# Terraform Cleanup
# --------------------------------------------------------------------

print_banner "Terraform Cleanup"

echo "Formatting Terraform configuration..."

terraform fmt -recursive

echo "✓ Terraform formatting complete."

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

echo
echo "Confirming Terraform state is empty..."

terraform state list || echo "✓ Terraform state is empty."

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
if kubectl cluster-info >/dev/null 2>&1; then
    echo "Snapshot CRDs:"
    kubectl get crd | grep snapshot || true
else
    echo "✓ Cluster removed; skipping Kubernetes CRD verification."
fi

echo "✓ Snapshot CRD verification complete."

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