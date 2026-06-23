#!/bin/bash

set -e

export AWS_PAGER=""

CLUSTER_NAME="jenkins-eks"
AWS_REGION="eu-west-2"

echo ""
echo "WARNING: This will destroy the entire Jenkins EKS environment."
echo ""

read -p "Are you sure you want to continue? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo ""
    echo "Destroy cancelled."
    exit 0
fi

echo ""
echo "Starting environment cleanup..."

echo ""
echo "Checking cluster connection..."
kubectl get nodes

echo ""
echo "Deleting Jenkins ingress..."
echo ""

kubectl delete -f jenkins-ingress.yaml --ignore-not-found=true

echo ""
echo "Waiting for ALB cleanup..."
echo ""

sleep 120

echo ""
echo "Deleting Jenkins service..."
kubectl delete -f jenkins-service.yaml --ignore-not-found=true

echo ""
echo "Deleting Jenkins deployment..."
kubectl delete -f jenkins-deployment.yaml --ignore-not-found=true

echo ""
echo "Deleting Jenkins PVC..."
kubectl delete -f jenkins-pvc.yaml --ignore-not-found=true

echo ""
echo "Deleting Jenkins namespace..."
kubectl delete namespace jenkins --ignore-not-found=true

echo ""
echo "Waiting for namespace deletion..."

kubectl wait \
  --for=delete namespace/jenkins \
  --timeout=120s || true

echo ""
echo "Current cluster resources:"
kubectl get pods -A

echo ""
echo "Checking load balancers..."
aws elbv2 describe-load-balancers --region $AWS_REGION

echo ""
echo "Running terraform destroy..."
# 
terraform plan -destroy -out=destroy.tfplan

read -p "Proceed with terraform destroy? (yes/no): " destroy_confirm

if [ "$destroy_confirm" != "yes" ]; then
    echo "Destroy cancelled."
    exit 0
fi

terraform apply destroy.tfplan

echo ""
echo "Checking for remaining VPCs..."
aws ec2 describe-vpcs \
  --filters Name=tag:Name,Values=jenkins-vpc \
  --region $AWS_REGION

echo ""
echo "Checking for remaining CloudWatch log groups..."

aws logs describe-log-groups \
  --log-group-name-prefix /aws/eks/jenkins-eks \
  --region $AWS_REGION

  
echo ""
echo "Checking for remaining EBS volumes..."

aws ec2 describe-volumes \
  --region $AWS_REGION \
  --filters Name=tag:KubernetesCluster,Values=jenkins-eks

echo ""
echo "Deleting orphaned CloudWatch log group if present..."

aws logs delete-log-group \
  --log-group-name /aws/eks/${CLUSTER_NAME}/cluster \
  --region $AWS_REGION 2>/dev/null || true

echo ""
echo "Verifying CloudWatch cleanup..."

aws logs describe-log-groups \
  --log-group-name-prefix /aws/eks/jenkins-eks \
  --region $AWS_REGION

echo ""
echo "Destroy completed."


