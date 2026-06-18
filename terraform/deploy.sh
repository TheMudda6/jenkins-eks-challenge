#!/bin/bash

set -euo pipefail

trap 'echo ""; echo "ERROR: Deployment failed on line $LINENO"; exit 1' ERR

echo ""
echo "====================================="
echo "Starting Jenkins EKS Deployment"
echo "====================================="
echo ""

terraform apply -auto-approve

echo ""
echo "Terraform deployment complete"
echo ""

aws eks update-kubeconfig \
  --region eu-west-2 \
  --name jenkins-eks

echo ""
echo "Kubeconfig updated"
echo ""

kubectl get nodes

echo ""
echo "Cluster connectivity verified"
echo ""

kubectl get storageclass

echo ""
echo "StorageClass verified"
echo ""

kubectl create namespace jenkins --dry-run=client -o yaml | kubectl apply -f -

echo ""
echo "Namespace ready"
echo ""

kubectl apply -f jenkins-pvc.yaml

echo ""
echo "PVC created"
echo ""

kubectl wait \
  --for=condition=ready pod \
  -l app=jenkins \
  -n jenkins \
  --timeout=300s

sleep 10

kubectl wait \
  --for=jsonpath='{.status.phase}'=Bound \
  pvc/jenkins-pvc \
  -n jenkins \
  --timeout=120s

echo ""
echo "PVC successfully bound"
echo ""

kubectl apply -f jenkins-deployment.yaml

echo ""
echo "Deployment created"
echo ""

kubectl apply -f jenkins-service.yaml

echo ""
echo "Service created"
echo ""

kubectl wait \
  --for=condition=ready pod \
  -l app=jenkins \
  -n jenkins \
  --timeout=300s

echo ""
echo "Jenkins pod is ready"
echo ""

kubectl get pods -n jenkins

echo ""
echo "Pod status verified"
echo ""

kubectl get pvc -n jenkins

echo ""
echo "PVC status verified"
echo ""

kubectl get svc -n jenkins

echo ""
echo "Service status verified"
echo ""

echo "====================================="
echo "Jenkins Deployment Complete"
echo "====================================="
echo ""
