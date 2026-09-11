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

PROJECT_VPC_ID="$(
  aws ec2 describe-vpcs \
    --region "$AWS_REGION" \
    --filters "Name=tag:Name,Values=jenkins-vpc" \
    --query 'Vpcs[0].VpcId' \
    --output text
)"

if [[ "$PROJECT_VPC_ID" == "None" ]]; then
  PROJECT_VPC_ID=""
fi

if [[ -n "$PROJECT_VPC_ID" ]]; then
  echo "Jenkins VPC: $PROJECT_VPC_ID"
else
  echo "Jenkins VPC does not exist."
fi

PROJECT_EIP_ALLOCATIONS=""

if [[ -n "$PROJECT_VPC_ID" ]]; then
  PROJECT_EIP_ALLOCATIONS="$(
    aws ec2 describe-nat-gateways --region "$AWS_REGION" --filter "Name=vpc-id,Values=$PROJECT_VPC_ID" --query 'NatGateways[].NatGatewayAddresses[].AllocationId' --output text
  )"
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
echo "Deleting ArgoCD child Applications..."

for application in \
  e-commerce-dev \
  e-commerce-prod \
  postgres \
  redis \
  secrets \
  storage \
  monitoring \
  monitoring-stack
do
  kubectl delete application "$application" \
    -n argocd \
    --ignore-not-found=true
done

echo
echo "Waiting for ArgoCD child Applications to disappear..."

for application in \
  e-commerce-dev \
  e-commerce-prod \
  postgres \
  redis \
  secrets \
  storage \
  monitoring \
  monitoring-stack
do
  kubectl wait \
    --for=delete \
    "application/$application" \
    -n argocd \
    --timeout=120s \
    2>/dev/null || true
done

echo "✓ ArgoCD Applications released."

print_banner "Cleaning Up Traefik Load Balancer"

TRAEFIK_NLB_ARN=""

TRAEFIK_CANDIDATES="$(
  aws elbv2 describe-load-balancers \
    --region "$AWS_REGION" \
    --query 'LoadBalancers[?contains(LoadBalancerName, `traefik`)].{Arn:LoadBalancerArn,VpcId:VpcId}' \
    --output text
)"

while read -r candidate_arn candidate_vpc; do
  if [[ "$candidate_vpc" == "$PROJECT_VPC_ID" ]]; then
    TRAEFIK_NLB_ARN="$candidate_arn"
    break
  fi
done <<< "$TRAEFIK_CANDIDATES"

if [[ -n "$TRAEFIK_NLB_ARN" ]]; then
  echo "Found Traefik Load Balancer:"
  echo "$TRAEFIK_NLB_ARN"
fi

if kubectl get namespace traefik >/dev/null 2>&1; then
  echo "Deleting Traefik Helm release..."

  if helm uninstall traefik \
    --namespace traefik \
    --wait \
    --timeout 5m; then
    echo "✓ Traefik Helm release removed."
  else
    echo "WARNING: Traefik Helm uninstall did not complete cleanly."
  fi

  terraform state rm 'helm_release.traefik' 2>/dev/null || true
  echo "✓ Traefik released from Terraform state."
fi

if [[ -n "$TRAEFIK_NLB_ARN" ]]; then
  echo "Waiting for Traefik Load Balancer to disappear..."

  for attempt in {1..60}; do
    if TRAEFIK_LB_ERROR="$(aws elbv2 describe-load-balancers \
      --region "$AWS_REGION" \
      --load-balancer-arns "$TRAEFIK_NLB_ARN" \
      2>&1)"; then
      sleep 5
      continue
    fi

    if grep -q "LoadBalancerNotFound" <<< "$TRAEFIK_LB_ERROR"; then
      echo "✓ Traefik Load Balancer is gone."
      TRAEFIK_NLB_ARN=""
      break
    fi

    echo "$TRAEFIK_LB_ERROR"
    echo "ERROR: Failed to check Traefik Load Balancer status."
    exit 1
  done

  if [[ -n "$TRAEFIK_NLB_ARN" ]]; then
    echo "WARNING: Traefik Load Balancer still exists."
    echo "Deleting the remaining Traefik Load Balancer directly..."

    aws elbv2 delete-load-balancer \
      --region "$AWS_REGION" \
      --load-balancer-arn "$TRAEFIK_NLB_ARN"

    echo "✓ Traefik Load Balancer deletion requested."
    echo "Waiting for Traefik Load Balancer deletion..."

    for attempt in {1..60}; do
      if TRAEFIK_LB_ERROR="$(aws elbv2 describe-load-balancers \
        --region "$AWS_REGION" \
        --load-balancer-arns "$TRAEFIK_NLB_ARN" \
        2>&1)"; then
        sleep 5
        continue
      fi

      if grep -q "LoadBalancerNotFound" <<< "$TRAEFIK_LB_ERROR"; then
        echo "✓ Traefik Load Balancer is fully deleted."
        TRAEFIK_NLB_ARN=""
        break
      fi

      echo "$TRAEFIK_LB_ERROR"
      echo "ERROR: Failed to verify Traefik Load Balancer deletion."
      exit 1
    done

    if [[ -n "$TRAEFIK_NLB_ARN" ]]; then
      echo "ERROR: Traefik Load Balancer still exists after deletion request."
      exit 1
    fi
  fi
else
  echo "✓ No Traefik Load Balancer found."
fi

  else

    echo "WARNING: Kubernetes API is unavailable."
    echo "Skipping Kubernetes cleanup."

  fi
fi

# ------------------------------------------------------------
# Terraform destroy plan
# ------------------------------------------------------------

# ------------------------------------------------------------
# Kubernetes security group cleanup
# ------------------------------------------------------------

print_banner "Cleaning Up Kubernetes Security Groups"

VPC_ID="$(
  aws ec2 describe-vpcs \
    --region "$AWS_REGION" \
    --filters "Name=tag:Name,Values=jenkins-vpc" \
    --query 'Vpcs[0].VpcId' \
    --output text
)"

if [[ -n "$VPC_ID" && "$VPC_ID" != "None" ]]; then
  for group_name in \
    "k8s-traffic-jenkinseks-*" \
    "k8s-traefik-traefik-*"
  do
    GROUP_IDS="$(
      aws ec2 describe-security-groups \
        --region "$AWS_REGION" \
        --filters \
          "Name=vpc-id,Values=$VPC_ID" \
          "Name=group-name,Values=$group_name" \
        --query 'SecurityGroups[].GroupId' \
        --output text
    )"

    for group_id in $GROUP_IDS; do
      echo "Cleaning up Kubernetes security group: $group_id"

      for attempt in {1..12}; do
        if aws ec2 delete-security-group \
          --region "$AWS_REGION" \
          --group-id "$group_id" \
          >/dev/null 2>&1; then
          echo "✓ Deleted security group: $group_id"
          break
        fi

        if [[ "$attempt" -eq 12 ]]; then
          echo "ERROR: Could not delete security group: $group_id"
          exit 1
        fi

        sleep 5
      done
    done
  done
else
  echo "✓ VPC no longer exists; no Kubernetes security groups to clean up."
fi

# ------------------------------------------------------------
# Terraform destroy plan
# ------------------------------------------------------------

print_banner "Preserving ECR Repositories"

for service in \
  api-gateway \
  order-service \
  inventory-service \
  payment-service \
  notification-service \
  shipping-service \
  dashboard-api \
  scheduler \
  worker
do
  terraform state rm \
    "module.ecr.aws_ecr_repository.services[\"$service\"]" \
    2>/dev/null || true
done

echo "✓ ECR repositories released from Terraform state."
echo "✓ ECR repositories and images will be preserved."

print_banner "Terraform Destroy Plan"

KUBERNETES_HOST="$(terraform output -raw cluster_endpoint)"
KUBERNETES_CA_CERTIFICATE="$(terraform output -raw cluster_certificate_authority_data)"
KUBERNETES_CLUSTER_NAME="$(terraform output -raw cluster_name)"

terraform plan -destroy \
  -var="terraform_bootstrap=false" \
  -var="kubernetes_host=$KUBERNETES_HOST" \
  -var="kubernetes_ca_certificate=$KUBERNETES_CA_CERTIFICATE" \
  -var="kubernetes_cluster_name=$KUBERNETES_CLUSTER_NAME" \
  -out=destroy.tfplan

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

if terraform apply -auto-approve destroy.tfplan; then
  rm -f destroy.tfplan
  echo "✓ Terraform infrastructure destroyed."
else
  echo
  echo "WARNING: Terraform destroy encountered an error."
  echo "Waiting 30 seconds before retrying with a fresh destroy plan..."
  echo

  rm -f destroy.tfplan

  sleep 30

  print_banner "Terraform Destroy Retry"

  terraform plan -destroy \
  -var="terraform_bootstrap=false" \
  -var="kubernetes_host=$KUBERNETES_HOST" \
  -var="kubernetes_ca_certificate=$KUBERNETES_CA_CERTIFICATE" \
  -var="kubernetes_cluster_name=$KUBERNETES_CLUSTER_NAME" \
  -out=destroy-retry.tfplan

  terraform apply -auto-approve destroy-retry.tfplan

  rm -f destroy-retry.tfplan

  echo "✓ Terraform infrastructure destroyed."
fi

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

REMAINING_CLUSTERS="$(
  aws eks list-clusters \
    --region "$AWS_REGION" \
    --query 'clusters[]' \
    --output text
)"

if [[ -n "$REMAINING_CLUSTERS" ]]; then
  echo "$REMAINING_CLUSTERS"
  echo "ERROR: EKS clusters still exist."
  exit 1
fi

echo "✓ No EKS clusters remain."
echo
echo "Remaining Jenkins VPCs:"

REMAINING_VPCS="$(
  aws ec2 describe-vpcs \
    --region "$AWS_REGION" \
    --filters "Name=tag:Name,Values=jenkins-vpc" \
    --query 'Vpcs[].VpcId' \
    --output text
)"

if [[ -n "$REMAINING_VPCS" ]]; then
  echo "$REMAINING_VPCS"
  echo "ERROR: Jenkins VPCs still exist."
  exit 1
fi

echo "✓ No Jenkins VPCs remain."
echo
echo "Remaining Load Balancers:"

REMAINING_LOAD_BALANCERS="$(
  aws elbv2 describe-load-balancers \
    --region "$AWS_REGION" \
    --query 'LoadBalancers[].LoadBalancerArn' \
    --output text
)"

if [[ -n "$REMAINING_LOAD_BALANCERS" ]]; then
  echo "$REMAINING_LOAD_BALANCERS"
  echo "ERROR: Load Balancers still exist."
  exit 1
fi

echo "✓ No Load Balancers remain."

echo
echo "Remaining EKS CloudWatch log groups:"

REMAINING_LOG_GROUPS="$(
  aws logs describe-log-groups \
    --region "$AWS_REGION" \
    --log-group-name-prefix "/aws/eks/$CLUSTER_NAME" \
    --query 'logGroups[].logGroupName' \
    --output text
)"

if [[ -n "$REMAINING_LOG_GROUPS" ]]; then
  echo "$REMAINING_LOG_GROUPS"
  echo "ERROR: EKS CloudWatch log groups still exist."
  exit 1
fi

echo "✓ No EKS CloudWatch log groups remain."

echo
echo "Remaining project SQS queues:"

REMAINING_QUEUES="$(
  aws sqs list-queues \
    --region "$AWS_REGION" \
    --queue-name-prefix "jenkins-eks-challenge-dev-" \
    --query 'QueueUrls[]' \
    --output text
)"

if [[ "$REMAINING_QUEUES" == "None" ]]; then
  REMAINING_QUEUES=""
fi

if [[ -n "$REMAINING_QUEUES" ]]; then
  echo "$REMAINING_QUEUES"
  echo "ERROR: Project SQS queues still exist."
  exit 1
fi

echo "✓ No project SQS queues remain."

echo "Remaining Kubernetes security groups:"

if [[ -n "$PROJECT_VPC_ID" ]]; then
  REMAINING_K8S_SGS="$(
    aws ec2 describe-security-groups \
      --region "$AWS_REGION" \
      --filters \
        "Name=vpc-id,Values=$PROJECT_VPC_ID" \
        "Name=group-name,Values=k8s-traffic-jenkinseks-*,k8s-traefik-traefik-*" \
      --query 'SecurityGroups[].GroupId' \
      --output text
  )"

  if [[ -n "$REMAINING_K8S_SGS" && "$REMAINING_K8S_SGS" != "None" ]]; then
    echo "$REMAINING_K8S_SGS"
    echo "ERROR: Kubernetes security groups still exist."
    exit 1
  fi
fi

echo "✓ No targeted Kubernetes security groups remain."

echo
echo "Preserved project ECR repositories:"
aws ecr describe-repositories \
  --region "$AWS_REGION" \
  --query 'repositories[?starts_with(repositoryName, `jenkins-eks-challenge-dev-`)].repositoryName' \
  --output text

echo
echo "Remaining NAT gateways:"

REMAINING_NAT_GATEWAYS="$(
  aws ec2 describe-nat-gateways \
    --region "$AWS_REGION" \
    --filter "Name=state,Values=pending,available,deleting" \
    --query 'NatGateways[].NatGatewayId' \
    --output text
)"

if [[ -n "$REMAINING_NAT_GATEWAYS" ]]; then
  echo "$REMAINING_NAT_GATEWAYS"
  echo "ERROR: NAT gateways still exist."
  exit 1
fi

echo "✓ No NAT gateways remain."

echo

echo
echo "Remaining Elastic IPs:"

REMAINING_EIPS=false

if [[ -n "$PROJECT_EIP_ALLOCATIONS" ]]; then
  for allocation_id in $PROJECT_EIP_ALLOCATIONS; do
    if aws ec2 describe-addresses \
      --region "$AWS_REGION" \
      --allocation-ids "$allocation_id" \
      >/dev/null 2>&1; then
      echo "$allocation_id"
      REMAINING_EIPS=true
    fi
  done
fi

if [[ "$REMAINING_EIPS" == true ]]; then
  echo "ERROR: Project Elastic IPs still exist."
  exit 1
fi

echo "✓ No project Elastic IPs remain."

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