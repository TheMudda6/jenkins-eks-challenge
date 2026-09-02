#!/bin/bash

set -euo pipefail

cleanup() {
    rm -f tfplan destroy.tfplan
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

export AWS_PAGER=""

# --------------------------------------------------------------------
# Cleanup Configuration
# --------------------------------------------------------------------

AWS_REGION="eu-west-2"
CLUSTER_NAME="jenkins-eks"
NAMESPACE="jenkins"

# --------------------------------------------------------------------
# Helper Functions
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
# EKS Cluster Existence Check
#
# Purpose:
# Determine whether Kubernetes cleanup is required.
#
# If the cluster has already been destroyed, Kubernetes cleanup is
# skipped and Terraform/AWS cleanup continues.
#
# If the cluster is currently DELETING, Kubernetes cleanup is also
# skipped because the API server may no longer be reachable.
# --------------------------------------------------------------------

print_banner "Checking EKS Cluster"

EKS_STATUS="$(
    aws eks describe-cluster \
        --name "$CLUSTER_NAME" \
        --region "$AWS_REGION" \
        --query 'cluster.status' \
        --output text \
        2>/dev/null || true
)"

if [[ -z "$EKS_STATUS" || "$EKS_STATUS" == "None" ]]; then

    CLUSTER_EXISTS=false

    echo "✓ EKS cluster '$CLUSTER_NAME' does not exist."
    echo "Skipping Kubernetes cleanup."

elif [[ "$EKS_STATUS" == "DELETING" ]]; then

    CLUSTER_EXISTS=false

    echo "EKS cluster '$CLUSTER_NAME' is currently DELETING."
    echo "Skipping Kubernetes cleanup because the cluster is unavailable."

else

    CLUSTER_EXISTS=true

    echo "EKS cluster status: $EKS_STATUS"

    # ----------------------------------------------------------------
    # Kubernetes Cleanup
    # ----------------------------------------------------------------

    print_banner "Cleaning Kubernetes Resources"

    echo "Checking cluster connectivity..."

    if ! kubectl cluster-info >/dev/null 2>&1; then
        echo
        echo "ERROR: EKS cluster exists, but kubectl cannot connect."
        echo
        echo "Cluster: $CLUSTER_NAME"
        echo "Region:  $AWS_REGION"
        echo
        echo "The cluster must be reachable before Kubernetes resources"
        echo "can be safely cleaned up."
        exit 1
    fi

    kubectl get nodes

    echo "✓ Cluster connectivity verified."

    # ----------------------------------------------------------------
    # ArgoCD Application
    # ----------------------------------------------------------------

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

    # ----------------------------------------------------------------
    # Jenkins Ingress
    # ----------------------------------------------------------------

    echo "Deleting Jenkins ingress..."

    kubectl delete \
        -f infrastructure/jenkins/jenkins-ingress.yaml \
        --ignore-not-found=true

    echo "✓ Jenkins ingress deletion requested."

    kubectl wait \
        --for=delete \
        ingress/jenkins-ingress \
        -n "$NAMESPACE" \
        --timeout=300s || true

    echo "✓ Jenkins ingress cleanup complete."

    # ----------------------------------------------------------------
    # External Secrets Cleanup
    # ----------------------------------------------------------------

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
    echo "Deleting generated PostgreSQL Secret..."

    kubectl delete secret postgres-secret \
        -n "$NAMESPACE" \
        --ignore-not-found=true

    echo "✓ PostgreSQL Kubernetes Secret deleted."

    # ----------------------------------------------------------------
    # PostgreSQL Cleanup
    # ----------------------------------------------------------------

    print_banner "Removing PostgreSQL"

    echo "Deleting PostgreSQL StatefulSet..."

    kubectl delete \
        -f infrastructure/postgres/postgres-statefulset.yaml \
        --ignore-not-found=true

    echo "✓ PostgreSQL StatefulSet deletion requested."

    echo
    echo "Waiting for PostgreSQL StatefulSet to terminate..."

    kubectl wait \
        --for=delete \
        statefulset/postgres \
        -n "$NAMESPACE" \
        --timeout=300s || true

    echo "✓ PostgreSQL StatefulSet cleanup complete."

    echo
    echo "Checking PostgreSQL Pods..."

    kubectl get pods \
        -l app=postgres \
        -n "$NAMESPACE" || true

    # ----------------------------------------------------------------
    # PostgreSQL PVC / Retained PV
    # ----------------------------------------------------------------

    echo
    echo "Checking PostgreSQL PVC..."

    POSTGRES_PV="$(
        kubectl get pvc postgres-data-postgres-0 \
            -n "$NAMESPACE" \
            -o jsonpath='{.spec.volumeName}' \
            2>/dev/null || true
    )"

    if [ -n "$POSTGRES_PV" ]; then
        echo "✓ PostgreSQL PV identified: $POSTGRES_PV"
    else
        echo "No PostgreSQL PV found."
    fi

    echo
    echo "Deleting PostgreSQL PVC..."

    kubectl delete \
        pvc/postgres-data-postgres-0 \
        -n "$NAMESPACE" \
        --ignore-not-found=true

    echo "✓ PostgreSQL PVC deletion requested."

    echo
    echo "Waiting for PostgreSQL PVC removal..."

    if kubectl wait \
        --for=delete \
        pvc/postgres-data-postgres-0 \
        -n "$NAMESPACE" \
        --timeout=300s; then

        echo "✓ PostgreSQL PVC removed."

    else

        echo "WARNING: PostgreSQL PVC still exists after timeout."

    fi

    # ----------------------------------------------------------------
    # PostgreSQL PV Retention
    #
    # The gp3-retain StorageClass intentionally retains the PV/EBS
    # volume after the PVC is deleted.
    # ----------------------------------------------------------------

    if [ -n "$POSTGRES_PV" ]; then

        echo
        echo "Checking PostgreSQL PV retention..."

        if kubectl get pv "$POSTGRES_PV" >/dev/null 2>&1; then

            PV_STATUS="$(
                kubectl get pv "$POSTGRES_PV" \
                    -o jsonpath='{.status.phase}' \
                    2>/dev/null || true
            )"

            echo "PostgreSQL PV: $POSTGRES_PV"
            echo "PV status: $PV_STATUS"

            if [[ "$PV_STATUS" == "Released" || "$PV_STATUS" == "Available" ]]; then

                echo "✓ PostgreSQL PV retained as expected."

            elif [[ "$PV_STATUS" == "Bound" ]]; then

                echo "WARNING: PostgreSQL PV is still Bound."

            else

                echo "WARNING: PostgreSQL PV is in unexpected state: $PV_STATUS"

            fi

        else

            echo "WARNING: PostgreSQL PV no longer exists."

        fi

    fi

    # ----------------------------------------------------------------
    # PostgreSQL Service
    # ----------------------------------------------------------------

    echo
    echo "Deleting PostgreSQL Service..."

    kubectl delete \
        -f infrastructure/postgres/postgres-service.yaml \
        --ignore-not-found=true

    echo "✓ PostgreSQL Service deleted."

    # ----------------------------------------------------------------
    # Redis Cleanup
    # ----------------------------------------------------------------

    print_banner "Removing Redis"

    echo "Deleting Redis StatefulSet..."

    kubectl delete \
        -f infrastructure/redis/redis-statefulset.yaml \
        --ignore-not-found=true

    echo "✓ Redis StatefulSet deletion requested."

    echo
    echo "Waiting for Redis Pod removal..."

    kubectl wait \
        --for=delete \
        pod/redis-0 \
        -n "$NAMESPACE" \
        --timeout=120s || true

    echo "✓ Redis Pod cleanup complete."

    echo
    echo "Deleting Redis PVC..."

    kubectl delete \
        pvc/redis-data-redis-0 \
        -n "$NAMESPACE" \
        --ignore-not-found=true

    echo "✓ Redis PVC deletion requested."

    echo
    echo "Waiting for Redis PVC removal..."

    kubectl wait \
        --for=delete \
        pvc/redis-data-redis-0 \
        -n "$NAMESPACE" \
        --timeout=120s || true

    echo "✓ Redis PVC cleanup complete."

    echo
    echo "Deleting Redis Service..."

    kubectl delete \
        -f infrastructure/redis/redis-service.yaml \
        --ignore-not-found=true

    echo "✓ Redis Service deleted."

    echo
    echo "Redis resources after cleanup:"

    kubectl get statefulset redis \
        -n "$NAMESPACE" \
        2>/dev/null || true

    kubectl get pods \
        -l app=redis \
        -n "$NAMESPACE" \
        2>/dev/null || true

    kubectl get pvc redis-data-redis-0 \
        -n "$NAMESPACE" \
        2>/dev/null || true

    kubectl get svc redis \
        -n "$NAMESPACE" \
        2>/dev/null || true

    echo
    echo "✓ Redis cleanup complete."

    # ----------------------------------------------------------------
    # Jenkins Cleanup
    # ----------------------------------------------------------------

    print_banner "Removing Jenkins"

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

    echo "✓ Jenkins PVC cleanup complete."

    # ----------------------------------------------------------------
    # Monitoring Cleanup
    # ----------------------------------------------------------------

    print_banner "Removing Monitoring"

    echo "Deleting Monitoring ArgoCD Application..."

    kubectl delete application monitoring \
        -n argocd \
        --ignore-not-found=true

    echo "✓ Monitoring ArgoCD Application deleted."

    echo
    echo "Waiting for Monitoring resources to release..."

    sleep 30

    echo "✓ Monitoring resources released."

    echo
    echo "Deleting Monitoring namespace..."

    kubectl delete namespace monitoring \
        --ignore-not-found=true

    echo "✓ Monitoring namespace deletion requested."

    kubectl wait \
        --for=delete \
        namespace/monitoring \
        --timeout=120s || true

    echo "✓ Monitoring namespace cleanup complete."

    # ----------------------------------------------------------------
    # Remaining Secret Resources
    # ----------------------------------------------------------------

    echo
    echo "Remaining External Secrets:"

    kubectl get externalsecret -A || true

    echo
    echo "Remaining ClusterSecretStores:"

    kubectl get clustersecretstore || true

    # ----------------------------------------------------------------
    # Jenkins Namespace
    # ----------------------------------------------------------------

    echo
    echo "Deleting Jenkins namespace..."

    kubectl delete namespace "$NAMESPACE" \
        --ignore-not-found=true

    echo "✓ Jenkins namespace deletion requested."

    kubectl wait \
        --for=delete \
        namespace/"$NAMESPACE" \
        --timeout=120s || true

    echo "✓ Jenkins namespace cleanup complete."

    # ----------------------------------------------------------------
    # Kubernetes Cleanup Verification
    # ----------------------------------------------------------------

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

    # ----------------------------------------------------------------
    # Snapshot Infrastructure
    # ----------------------------------------------------------------

    print_banner "Removing Snapshot Infrastructure"

    if [ -f infrastructure/snapshot/uninstall.sh ]; then

        bash infrastructure/snapshot/uninstall.sh

    else

        echo "Snapshot uninstall script not found. Skipping."

    fi

    echo "✓ Snapshot infrastructure cleanup complete."

    # ----------------------------------------------------------------
    # Storage Cleanup
    # ----------------------------------------------------------------

    print_banner "Removing Storage Resources"

    kubectl delete \
        -f infrastructure/storage/gp3-retain-storageclass.yaml \
        --ignore-not-found=true

    echo "✓ gp3-retain StorageClass deleted."

    kubectl delete \
        -f infrastructure/storage/gp3-storageclass.yaml \
        --ignore-not-found=true

    echo "✓ gp3 StorageClass deleted."

fi

# --------------------------------------------------------------------
# Terraform Cleanup
# --------------------------------------------------------------------

print_banner "Terraform Cleanup"

echo "Formatting Terraform configuration..."

terraform fmt -recursive

echo "✓ Terraform formatting complete."

echo
echo "Validating Terraform configuration..."

terraform validate

echo "✓ Terraform validation complete."

# --------------------------------------------------------------------
# Traefik NLB Cleanup
#
# This must happen before Karpenter and before Terraform destroys EKS.
# The AWS Load Balancer Controller needs to remain available to clean
# up the NLB created for the Traefik LoadBalancer Service.
# --------------------------------------------------------------------

if [[ "$CLUSTER_EXISTS" == true ]]; then

    print_banner "Removing Traefik NLB"

    TRAEFIK_NAMESPACE="traefik"
    TRAEFIK_SERVICE="traefik"

    echo "Checking for Traefik Service..."

    TRAEFIK_NLB_HOSTNAME="$(
        kubectl get service "$TRAEFIK_SERVICE" \
            -n "$TRAEFIK_NAMESPACE" \
            -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' \
            2>/dev/null || true
    )"

    if [[ -n "$TRAEFIK_NLB_HOSTNAME" ]]; then

        echo "Traefik NLB hostname:"
        echo "  $TRAEFIK_NLB_HOSTNAME"

        TRAEFIK_NLB_NAME="${TRAEFIK_NLB_HOSTNAME%%.elb.*}"

        echo
        echo "Deleting Traefik Service..."

        kubectl delete service "$TRAEFIK_SERVICE" \
            -n "$TRAEFIK_NAMESPACE" \
            --ignore-not-found=true \
            --wait=false

        echo "✓ Traefik Service deletion requested."

        echo
        echo "Waiting for AWS NLB to disappear..."

        for i in {1..36}; do

            if ! aws elbv2 describe-load-balancers \
                --region "$AWS_REGION" \
                --names "$TRAEFIK_NLB_NAME" \
                >/dev/null 2>&1; then

                echo "✓ Traefik NLB removed."
                break

            fi

            if [[ "$i" -eq 36 ]]; then

                echo
                echo "ERROR: Traefik NLB still exists after 6 minutes:"
                echo "  $TRAEFIK_NLB_NAME"
                exit 1

            fi

            echo "Waiting for Traefik NLB removal... ($i/36)"
            sleep 10

        done

        echo
        echo "Checking Traefik Service deletion..."

        for i in {1..12}; do

            if ! kubectl get service "$TRAEFIK_SERVICE" \
                -n "$TRAEFIK_NAMESPACE" \
                >/dev/null 2>&1; then

                echo "✓ Traefik Service removed."
                break

            fi

            if [[ "$i" -eq 12 ]]; then

                echo "Traefik Service is still present."
                echo "The NLB is already gone, so removing the AWS Load Balancer Controller finalizer..."

                kubectl patch service "$TRAEFIK_SERVICE" \
                    -n "$TRAEFIK_NAMESPACE" \
                    --type=json \
                    -p='[{"op":"remove","path":"/metadata/finalizers"}]' \
                    || true

                kubectl wait \
                    --for=delete \
                    "service/$TRAEFIK_SERVICE" \
                    -n "$TRAEFIK_NAMESPACE" \
                    --timeout=60s \
                    || {
                        echo "ERROR: Traefik Service could not be removed."
                        exit 1
                    }

                echo "✓ Stuck Traefik Service finalizer removed."
                break

            fi

            echo "Waiting for Traefik Service deletion... ($i/12)"
            sleep 5

        done

    else

        echo "No active Traefik NLB found."

        if kubectl get service "$TRAEFIK_SERVICE" \
            -n "$TRAEFIK_NAMESPACE" \
            >/dev/null 2>&1; then

            echo "Traefik Service exists without an active NLB."
            echo "Deleting Traefik Service..."

            kubectl delete service "$TRAEFIK_SERVICE" \
                -n "$TRAEFIK_NAMESPACE" \
                --ignore-not-found=true \
                --wait=false

            kubectl wait \
                --for=delete \
                "service/$TRAEFIK_SERVICE" \
                -n "$TRAEFIK_NAMESPACE" \
                --timeout=60s \
                || true

            echo "✓ Traefik Service cleanup complete."

        else

            echo "✓ Traefik Service does not exist."

        fi

    fi

    echo
    echo "✓ Traefik NLB cleanup complete."

else

    echo
    echo "Skipping Traefik Kubernetes cleanup because the EKS cluster is gone."

fi

# --------------------------------------------------------------------
# AWS Load Balancer Controller Security Group Cleanup
#
# These groups may remain after the LoadBalancer Service/NLB is gone.
# Only groups with a LoadBalancer description are considered.
# --------------------------------------------------------------------

print_banner "Removing Load Balancer Security Groups"

VPC_ID="$(
    aws ec2 describe-vpcs \
        --region "$AWS_REGION" \
        --filters "Name=tag:Name,Values=jenkins-vpc" \
        --query 'Vpcs[0].VpcId' \
        --output text \
        2>/dev/null || true
)"

if [[ -n "$VPC_ID" && "$VPC_ID" != "None" ]]; then

    echo "Target VPC: $VPC_ID"

    echo
    echo "Finding AWS Load Balancer Controller security groups..."

    LB_SECURITY_GROUPS="$(
        aws ec2 describe-security-groups \
            --region "$AWS_REGION" \
            --filters "Name=vpc-id,Values=$VPC_ID" \
            --query 'SecurityGroups[?GroupName!=`default` && contains(Description, `LoadBalancer`)].{ID:GroupId,Name:GroupName}' \
            --output text \
            2>/dev/null || true
    )"

    if [[ -z "$LB_SECURITY_GROUPS" ]]; then

        echo "✓ No Load Balancer security groups found."

    else

        while read -r SG_ID SG_NAME; do

            [[ -z "$SG_ID" ]] && continue

            echo
            echo "Found security group:"
            echo "  ID:   $SG_ID"
            echo "  Name: $SG_NAME"

            echo "Checking for attached network interfaces..."

            ENI_COUNT="$(
                aws ec2 describe-network-interfaces \
                    --region "$AWS_REGION" \
                    --filters "Name=group-id,Values=$SG_ID" \
                    --query 'length(NetworkInterfaces)' \
                    --output text \
                    2>/dev/null || echo "0"
            )"

            if [[ "$ENI_COUNT" != "0" ]]; then

                echo "ERROR: Security group $SG_ID still has $ENI_COUNT network interface(s)."

                aws ec2 describe-network-interfaces \
                    --region "$AWS_REGION" \
                    --filters "Name=group-id,Values=$SG_ID" \
                    --query 'NetworkInterfaces[].{ID:NetworkInterfaceId,Status:Status,Description:Description}' \
                    --output table

                exit 1

            fi

            echo "✓ No network interfaces attached."

            echo "Checking for security group references..."

            SG_REFERENCES="$(
                aws ec2 describe-security-groups \
                    --region "$AWS_REGION" \
                    --filters "Name=vpc-id,Values=$VPC_ID" \
                    --query "SecurityGroups[?IpPermissions[?UserIdGroupPairs[?GroupId=='$SG_ID']]] | [].GroupId" \
                    --output text \
                    2>/dev/null || true
            )"

            SG_EGRESS_REFERENCES="$(
                aws ec2 describe-security-groups \
                    --region "$AWS_REGION" \
                    --filters "Name=vpc-id,Values=$VPC_ID" \
                    --query "SecurityGroups[?IpPermissionsEgress[?UserIdGroupPairs[?GroupId=='$SG_ID']]] | [].GroupId" \
                    --output text \
                    2>/dev/null || true
            )"

            if [[ -n "$SG_REFERENCES" || -n "$SG_EGRESS_REFERENCES" ]]; then

                echo "ERROR: Security group $SG_ID is still referenced."
                echo "Ingress references: $SG_REFERENCES"
                echo "Egress references:  $SG_EGRESS_REFERENCES"
                exit 1

            fi

            echo "✓ No security group references found."

            echo "Deleting security group $SG_ID..."

            if aws ec2 delete-security-group \
                --region "$AWS_REGION" \
                --group-id "$SG_ID"; then

                echo "✓ Security group $SG_ID deleted."

            else

                echo "WARNING: Could not delete security group $SG_ID."
                echo "Terraform/VPC deletion will determine whether it is still required."

            fi

        done <<< "$LB_SECURITY_GROUPS"

    fi

else

    echo "✓ Target VPC no longer exists."

fi

echo
echo "✓ Load Balancer security group cleanup complete."

# --------------------------------------------------------------------
# Remaining ELB Network Interface Verification
# --------------------------------------------------------------------

echo
echo "Checking for remaining ELB network interfaces..."

VPC_ID="$(
    aws ec2 describe-vpcs \
        --region "$AWS_REGION" \
        --filters "Name=tag:Name,Values=jenkins-vpc" \
        --query 'Vpcs[0].VpcId' \
        --output text \
        2>/dev/null || true
)"

if [[ -n "$VPC_ID" && "$VPC_ID" != "None" ]]; then

    ELB_ENIS="$(
        aws ec2 describe-network-interfaces \
            --region "$AWS_REGION" \
            --filters \
                "Name=vpc-id,Values=$VPC_ID" \
                "Name=description,Values=ELB *" \
            --query 'NetworkInterfaces[].NetworkInterfaceId' \
            --output text \
            2>/dev/null || true
    )"

    if [[ -n "$ELB_ENIS" && "$ELB_ENIS" != "None" ]]; then

        echo "ERROR: ELB network interfaces still exist:"
        echo "$ELB_ENIS"
        exit 1

    fi

    echo "✓ No ELB network interfaces remain."

else

    echo "✓ Target VPC no longer exists."

fi

# --------------------------------------------------------------------
# Karpenter Cleanup
#
# This must happen before Terraform destroys the EKS cluster.
# --------------------------------------------------------------------

if [[ "$CLUSTER_EXISTS" == true ]]; then

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

    echo "✓ Karpenter NodePool cleanup complete."

    echo
    echo "Waiting for Karpenter-provisioned nodes to terminate..."

    KARPENTER_NODE_TIMEOUT=300
    KARPENTER_NODE_ELAPSED=0

    while kubectl get nodes \
        -l karpenter.sh/nodepool=default \
        --no-headers 2>/dev/null | grep -q .; do

        if [ "$KARPENTER_NODE_ELAPSED" -ge "$KARPENTER_NODE_TIMEOUT" ]; then

            echo "WARNING: Karpenter-provisioned nodes still exist after timeout."

            kubectl get nodes \
                -l karpenter.sh/nodepool=default || true

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

else

    print_banner "Karpenter Cleanup"

    echo "EKS cluster is already gone."
    echo "✓ Skipping Karpenter Kubernetes cleanup."

fi

# --------------------------------------------------------------------
# Stale Kubernetes / Helm Terraform State Cleanup
#
# If the EKS cluster is already gone, Terraform cannot refresh
# Kubernetes/Helm resources because their API endpoint no longer
# exists.
#
# Remove only those cluster-dependent resources from Terraform state.
# AWS infrastructure remains in Terraform state and can still be
# destroyed normally.
# --------------------------------------------------------------------

if [[ "$CLUSTER_EXISTS" == false ]]; then

    print_banner "Removing Stale Kubernetes Terraform State"

    echo "The EKS cluster is already gone."
    echo "Checking Terraform state for Kubernetes/Helm resources..."

    CLUSTER_RESOURCE_STATE="$(
        terraform state list 2>/dev/null |
            grep -E 'helm_release|kubernetes_|kubectl_' ||
            true
    )"

    if [[ -z "$CLUSTER_RESOURCE_STATE" ]]; then

        echo "✓ No stale Kubernetes/Helm Terraform resources found."

    else

        echo
        echo "The following cluster-dependent resources remain in Terraform state:"
        echo
        echo "$CLUSTER_RESOURCE_STATE"
        echo

        while IFS= read -r RESOURCE; do

            [[ -z "$RESOURCE" ]] && continue

            echo "Removing stale Terraform state:"
            echo "  $RESOURCE"

            terraform state rm "$RESOURCE"

            echo "✓ Removed: $RESOURCE"

        done <<< "$CLUSTER_RESOURCE_STATE"

        echo
        echo "✓ Stale Kubernetes/Helm Terraform state removed."

    fi

fi

# --------------------------------------------------------------------
# Terraform Destroy
# --------------------------------------------------------------------

print_banner "Terraform Destroy"

echo "Creating Terraform destroy plan..."

terraform plan -destroy -out=destroy.tfplan

echo "✓ Terraform destroy plan created."

echo
read -p "Proceed with Terraform destroy? (yes/no): " destroy_confirm

if [ "$destroy_confirm" != "yes" ]; then

    echo "Cleanup cancelled."
    exit 0

fi

echo
echo "Destroying Terraform infrastructure..."

terraform apply -auto-approve destroy.tfplan

echo "✓ Terraform infrastructure destroyed."

# --------------------------------------------------------------------
# Terraform State Verification
# --------------------------------------------------------------------

echo
echo "Confirming Terraform state is empty..."

TERRAFORM_STATE="$(
    terraform state list 2>/dev/null || true
)"

if [[ -n "$TERRAFORM_STATE" ]]; then

    echo "ERROR: Terraform state is not empty."
    echo "$TERRAFORM_STATE"
    exit 1

else

    echo "✓ Terraform state is empty."

fi

# --------------------------------------------------------------------
# Cleanup Verification
# --------------------------------------------------------------------

print_banner "Cleanup Verification"

echo
echo "Remaining EKS clusters:"

aws eks list-clusters \
    --region "$AWS_REGION"

echo
echo "Remaining Jenkins VPCs:"

aws ec2 describe-vpcs \
    --filters Name=tag:Name,Values=jenkins-vpc \
    --region "$AWS_REGION"

echo
echo "Remaining Load Balancers:"

aws elbv2 describe-load-balancers \
    --region "$AWS_REGION"

echo
echo "Remaining CloudWatch log groups:"

aws logs describe-log-groups \
    --log-group-name-prefix "/aws/eks/$CLUSTER_NAME" \
    --region "$AWS_REGION"

echo
echo "Remaining EBS volumes associated with the former cluster:"

aws ec2 describe-volumes \
    --region "$AWS_REGION" \
    --filters Name=tag:KubernetesCluster,Values="$CLUSTER_NAME"

# --------------------------------------------------------------------
# Kubernetes Snapshot Verification
#
# The cluster normally no longer exists at this point, so all
# kubectl checks are allowed to fail without failing the script.
# --------------------------------------------------------------------

echo
echo "VolumeSnapshotClasses:"

kubectl get volumesnapshotclass 2>/dev/null \
    || echo "✓ No VolumeSnapshotClasses found or cluster removed."

echo
echo "VolumeSnapshots:"

kubectl get volumesnapshot -A 2>/dev/null \
    || echo "✓ No VolumeSnapshots found or cluster removed."

echo
echo "VolumeSnapshotContents:"

kubectl get volumesnapshotcontent 2>/dev/null \
    || echo "✓ No VolumeSnapshotContents found or cluster removed."

echo
echo "Snapshot Controller:"

kubectl get deployment snapshot-controller \
    -n kube-system \
    2>/dev/null \
    || echo "✓ Snapshot Controller removed or cluster removed."

echo

if kubectl cluster-info >/dev/null 2>&1; then

    echo "Snapshot CRDs:"
    kubectl get crd | grep snapshot || true

else

    echo "✓ Cluster removed; skipping Kubernetes CRD verification."

fi

echo
echo "✓ Snapshot CRD verification complete."

echo
echo "✓ Verification complete."

print_banner "Cleanup Successful"

echo "The Jenkins Platform has been removed successfully."
echo
echo "Terraform-managed infrastructure has been destroyed."
echo
echo "AWS resources have been verified."
echo
echo "Temporary Terraform files have been removed."