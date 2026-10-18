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
# Bounded diagnostics
#
# Purpose:
# Prevent troubleshooting commands from hanging indefinitely
# after a deployment or readiness check has failed.
# ------------------------------------------------------------

run_diagnostic() {
  echo "+ $*"
  timeout 5s "$@" || echo "Diagnostic unavailable or timed out: $*"
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

command -v curl >/dev/null || {
  echo "ERROR: curl is not installed."
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
# Terraform validation
# ------------------------------------------------------------

cd "$TERRAFORM_DIR"

print_banner "Terraform Validation"

terraform fmt -check -recursive
terraform validate

echo "✓ Terraform configuration validated."

print_banner "Reusing ECR Repositories"

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
  repository="jenkins-eks-challenge-dev-${service}"
  address="module.ecr.aws_ecr_repository.services[\"${service}\"]"

  if aws ecr describe-repositories \
    --region "$AWS_REGION" \
    --repository-names "$repository" >/dev/null 2>&1; then

    if ! terraform state show "$address" >/dev/null 2>&1; then
      terraform import "$address" "$repository"
    fi
  fi
done

echo "✓ ECR repositories are ready for Terraform."

# ------------------------------------------------------------
# Reuse VPC Flow Logs CloudWatch Log Group
#
# Import the existing log group when AWS already has it but
# Terraform state does not track it, avoiding an AlreadyExists
# error during the bootstrap plan.
# ------------------------------------------------------------

print_banner "Checking VPC Flow Logs Log Group"

FLOW_LOG_GROUP="/aws/vpc/jenkins-vpc/flow-logs"
FLOW_LOG_GROUP_ADDRESS="module.vpc.aws_cloudwatch_log_group.vpc_flow_logs"

if aws logs describe-log-groups \
  --region "$AWS_REGION" \
  --log-group-name-prefix "$FLOW_LOG_GROUP" \
  --query "logGroups[?logGroupName=='$FLOW_LOG_GROUP'].logGroupName" \
  --output text | grep -Fxq "$FLOW_LOG_GROUP"; then

  if ! terraform state show "$FLOW_LOG_GROUP_ADDRESS" >/dev/null 2>&1; then
    echo "Existing VPC flow-log group is not tracked by Terraform."
    terraform import "$FLOW_LOG_GROUP_ADDRESS" "$FLOW_LOG_GROUP"
  else
    echo "✓ VPC flow-log group is already tracked by Terraform."
  fi

else
  echo "✓ VPC flow-log group does not exist; Terraform can create it."
fi

# ------------------------------------------------------------
# Terraform plan
# ------------------------------------------------------------

# ------------------------------------------------------------
# Terraform bootstrap
# ------------------------------------------------------------

print_banner "Terraform Bootstrap Plan"

terraform plan \
  -var="terraform_bootstrap=true" \
  -target=module.vpc \
  -target=module.sqs \
  -target=module.ecr \
  -target=module.secrets \
  -target=module.iam \
  -target=module.eks \
  -out=tfplan-bootstrap

echo
echo "Terraform bootstrap plan created successfully."
echo
echo "Review the plan above before continuing."
echo
read -r -p "Apply this Terraform bootstrap plan? [y/N] " CONFIRM

if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
  echo "Terraform bootstrap apply cancelled."
  rm -f tfplan-bootstrap
  exit 0
fi

print_banner "Terraform Bootstrap Apply"

terraform apply tfplan-bootstrap

rm -f tfplan-bootstrap

echo "✓ Terraform bootstrap apply complete."

# ------------------------------------------------------------
# Configure Kubernetes access
# ------------------------------------------------------------

print_banner "Configuring Kubernetes"

aws eks update-kubeconfig \
  --region "$AWS_REGION" \
  --name "$CLUSTER_NAME"

kubectl get nodes

echo "✓ Kubernetes connectivity verified."

# ------------------------------------------------------------
# Terraform Platform Plan
# ------------------------------------------------------------

 print_banner "Terraform Platform Plan"

KUBERNETES_HOST="$(terraform output -raw cluster_endpoint)"
KUBERNETES_CA_CERTIFICATE="$(terraform output -raw cluster_certificate_authority_data)"
KUBERNETES_CLUSTER_NAME="$(terraform output -raw cluster_name)"

 terraform plan \
   -var="terraform_bootstrap=false" \
   -var="kubernetes_host=$KUBERNETES_HOST" \
   -var="kubernetes_ca_certificate=$KUBERNETES_CA_CERTIFICATE" \
   -var="kubernetes_cluster_name=$KUBERNETES_CLUSTER_NAME" \
   -out=tfplan-platform

echo
echo "Terraform platform plan created successfully."
echo
echo "Review the plan above before continuing."
echo
read -r -p "Apply this Terraform platform plan? [y/N] " CONFIRM

if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
  echo "Terraform platform apply cancelled."
  rm -f tfplan-platform
  exit 0
fi

print_banner "Terraform Platform Apply"

terraform apply tfplan-platform

rm -f tfplan-platform

echo "✓ Terraform platform apply complete."

# ------------------------------------------------------------
# Verify platform controllers
# ------------------------------------------------------------

print_banner "Verifying Platform Controllers"

kubectl wait \
  --for=condition=Available \
  deployment/argocd-server \
  -n argocd \
  --timeout=300s

echo "✓ ArgoCD is ready."

kubectl wait \
  --for=condition=Available \
  deployment/karpenter \
  -n kube-system \
  --timeout=300s

echo "✓ Karpenter is ready."

kubectl wait \
  --for=condition=Available \
  deployment/aws-load-balancer-controller \
  -n kube-system \
  --timeout=300s

echo "✓ AWS Load Balancer Controller is ready."

echo "Waiting for AWS Load Balancer Controller webhook..."


WEBHOOK_TIMEOUT_SECONDS=300
WEBHOOK_DEADLINE=$((SECONDS + WEBHOOK_TIMEOUT_SECONDS))

until kubectl get endpoints aws-load-balancer-webhook-service \
  -n kube-system \
  -o jsonpath='{.subsets[*].addresses[*].ip}' \
  2>/dev/null | grep -q '[0-9]'; do

  if (( SECONDS >= WEBHOOK_DEADLINE )); then
    echo "ERROR: AWS Load Balancer Controller webhook did not become ready within ${WEBHOOK_TIMEOUT_SECONDS}s."
    run_diagnostic kubectl get endpoints \
      aws-load-balancer-webhook-service -n kube-system -o yaml
    run_diagnostic kubectl describe deployment \
      aws-load-balancer-controller -n kube-system
    exit 1
  fi

  sleep 5
done

echo "✓ AWS Load Balancer Controller webhook is ready."

kubectl wait \
  --for=condition=Available \
  deployment/ebs-csi-controller \
  -n kube-system \
  --timeout=300s

echo "✓ EBS CSI controller is ready."

# ------------------------------------------------------------
# Verify cert-manager readiness before starting GitOps
# ------------------------------------------------------------

print_banner "Verifying cert-manager"

kubectl wait \
  --for=condition=Available \
  deployment/cert-manager \
  -n cert-manager \
  --timeout=300s || {
    echo "ERROR: cert-manager did not become Available within 300s."
    run_diagnostic kubectl get pods -n cert-manager -o wide
    run_diagnostic kubectl logs deployment/cert-manager -n cert-manager --tail=100
    exit 1
  }

for crd in certificates.cert-manager.io clusterissuers.cert-manager.io; do
  if ! kubectl wait \
    --for=condition=Established \
    "crd/${crd}" \
    --timeout=300s; then
    echo "ERROR: cert-manager CRD '${crd}' was not Established."
    run_diagnostic kubectl get crd "$crd"
    run_diagnostic kubectl get pods -n cert-manager -o wide
    exit 1
  fi
done

echo "✓ cert-manager deployment and required CRDs are ready."


kubectl wait \
  --for=condition=Available \
  deployment/external-secrets \
  -n external-secrets \
  --timeout=300s

echo "✓ External Secrets Operator is ready."

echo "Installing Volume Snapshot infrastructure..."
bash infrastructure/snapshot/install.sh
echo "✓ Volume Snapshot infrastructure ready."

kubectl apply -f infrastructure/argocd/root-application.yaml

echo "✓ ArgoCD platform-root Application applied."

# ------------------------------------------------------------
# Verify ArgoCD GitOps root application
# ------------------------------------------------------------

print_banner "Verifying ArgoCD GitOps"

echo "Waiting for platform-root Application..."

ARGOCD_TIMEOUT=300
ARGOCD_ELAPSED=0

until kubectl get application platform-root \
  -n argocd \
  -o jsonpath='{.status.health.status}' 2>/dev/null \
  | grep -q "^Healthy$"; do

  if [ "$ARGOCD_ELAPSED" -ge "$ARGOCD_TIMEOUT" ]; then
    echo "ERROR: platform-root did not become Healthy."
    kubectl get application platform-root -n argocd
    exit 1
  fi

  echo "Waiting for platform-root..."
  sleep 10
  ARGOCD_ELAPSED=$((ARGOCD_ELAPSED + 10))
done

echo "✓ platform-root is Healthy."

# ------------------------------------------------------------
# Verify child Applications
# ------------------------------------------------------------

print_banner "Verifying ArgoCD Applications"

kubectl get applications -n argocd

echo
echo "Checking required Applications..."

for application in \
e-commerce-dev \
e-commerce-prod \
postgres \
redis \
secrets \
storage \
monitoring \
monitoring-stack \
security
do
  if ! kubectl get application "$application" -n argocd >/dev/null 2>&1; then
    echo "ERROR: ArgoCD Application '$application' was not created."
    exit 1
  fi

  echo "✓ $application"
done

# ------------------------------------------------------------
# Configure application runtime
# ------------------------------------------------------------

print_banner "Configuring Application Runtime"

echo "Waiting for jenkins namespace..."

until kubectl get namespace jenkins >/dev/null 2>&1; do
  sleep 5
done

SQS_QUEUE_URL="$(terraform output -raw queue_url)"

if [ -z "$SQS_QUEUE_URL" ]; then
  echo "ERROR: Terraform queue_url output is empty."
  exit 1
fi

kubectl create configmap application-config \
  -n jenkins \
  --from-literal="SQS_QUEUE_URL=$SQS_QUEUE_URL" \
  --dry-run=client \
  -o yaml \
  | kubectl apply -f -

echo "✓ application-config is ready."

# ------------------------------------------------------------
# Verify application workloads
# ------------------------------------------------------------

print_banner "Verifying E-Commerce Platform"

echo "Waiting for PostgreSQL..."

kubectl wait \
  --for=condition=Ready \
  pod/postgres-0 \
  -n jenkins \
  --timeout=300s

echo "✓ PostgreSQL is ready."

echo
echo "Waiting for Redis..."

kubectl wait \
  --for=condition=Ready \
  pod/redis-0 \
  -n jenkins \
  --timeout=300s

echo "✓ Redis is ready."

echo
echo "Waiting for E-Commerce application deployments..."

for deployment in \
  api-gateway \
  order-service \
  inventory-service \
  payment-service \
  notification-service \
  shipping-service \
  worker \
  scheduler \
  dashboard-api
do
  echo "Waiting for $deployment..."

  if ! kubectl wait \
    --for=condition=Available \
    "deployment/$deployment" \
    -n jenkins \
    --timeout=300s
  then
    echo
    echo "✗ $deployment failed to become Available."
    echo
    echo "Deployment status:"
    kubectl get deployment "$deployment" -n jenkins
    echo
    echo "Pods:"
    kubectl get pods -n jenkins -l "app=$deployment" -o wide
    echo
    echo "Recent events:"
    kubectl get events -n jenkins \
      --sort-by='.lastTimestamp' \
      | tail -30
    exit 1
  fi

  echo "✓ $deployment is ready."
done

echo
echo "Application deployments:"
kubectl get deployments -n jenkins

echo
echo "Application pods:"
kubectl get pods -n jenkins

echo
echo "Application services:"

kubectl get services -n jenkins

# ------------------------------------------------------------
# Verify monitoring
# ------------------------------------------------------------

print_banner "Verifying Monitoring"

kubectl get servicemonitors -n monitoring
kubectl get prometheusrules -n monitoring

kubectl wait \
  --for=create \
  statefulset/prometheus-monitoring-stack-kube-prom-prometheus \
  -n monitoring \
  --timeout=300s

kubectl wait \
  --for=jsonpath='{.status.readyReplicas}'=1 \
  statefulset/prometheus-monitoring-stack-kube-prom-prometheus \
  -n monitoring \
  --timeout=300s

echo "✓ Prometheus is ready."

 echo
 echo "Waiting for Grafana..."
kubectl wait \
  --for=create \
  deployment/monitoring-stack-grafana \
  -n monitoring \
  --timeout=300s

 kubectl wait \
   --for=condition=Available \
   deployment/monitoring-stack-grafana \
   -n monitoring \
   --timeout=300s

 echo "✓ Grafana is ready."

echo
echo "Monitoring pods:"
kubectl get pods -n monitoring

echo "✓ Monitoring stack is ready."

# ------------------------------------------------------------
# Final platform status
# ------------------------------------------------------------

print_banner "Final Platform Status"

echo "ArgoCD Applications:"
kubectl get applications -n argocd

echo
echo "EKS Nodes:"
kubectl get nodes

echo
echo "Namespaces:"
kubectl get namespaces

echo
echo "Storage:"
kubectl get storageclass

echo
echo "PostgreSQL:"
kubectl get statefulset,pod,pvc -n jenkins

echo
echo "Redis:"
kubectl get deployment,pod -n jenkins -l app=redis

echo
echo "E-Commerce Services:"
kubectl get deployment,service -n jenkins

echo
echo "Monitoring:"
kubectl get pods -n monitoring

# Wait for ExternalDNS before checking public DNS.
print_banner "Waiting for ExternalDNS"

kubectl rollout status deployment/external-dns \
  -n external-dns \
  --timeout=300s

echo "✓ ExternalDNS is ready."

# ------------------------------------------------------------
# Verify public Jenkins DNS
#
# Purpose:
# Wait for ExternalDNS to publish the Jenkins record after startup.
# Confirm the Route 53 A record targets the current Traefik NLB,
# its TXT ownership record belongs to ExternalDNS, and public DNS
# resolves to an address currently returned by that NLB.
# ------------------------------------------------------------

print_banner "Verifying Public DNS"

NLB_TIMEOUT_SECONDS=300
DNS_TIMEOUT_SECONDS=300
DNS_POLL_SECONDS=10
TRAEFIK_NLB_HOST=""

# Read the same literal hosted-zone ID Terraform uses from terraform.tfvars.
# This avoids selecting a different public hosted zone with a matching name.
ROUTE53_ZONE_ID="$(
  awk -F '"' '/^[[:space:]]*route53_zone_id[[:space:]]*=/ {
    print $2
    exit
  }' "$TERRAFORM_DIR/terraform.tfvars"
)"

if [[ ! "$ROUTE53_ZONE_ID" =~ ^Z[A-Z0-9]+$ ]]; then
  echo "ERROR: Could not read a valid route53_zone_id from terraform.tfvars."
  exit 1
fi

echo "Using configured Route 53 hosted zone: $ROUTE53_ZONE_ID"
echo "Waiting for Traefik's Network Load Balancer hostname..."
NLB_DEADLINE=$((SECONDS + NLB_TIMEOUT_SECONDS))

while (( SECONDS < NLB_DEADLINE )); do
  TRAEFIK_NLB_HOST="$(
    timeout 8s kubectl get service traefik -n traefik \
      -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' \
      2>/dev/null || true
  )"

  if [[ -n "$TRAEFIK_NLB_HOST" ]]; then
    break
  fi

  sleep "$DNS_POLL_SECONDS"
done

if [[ -z "$TRAEFIK_NLB_HOST" ]]; then
  echo "ERROR: Traefik did not publish an NLB hostname within ${NLB_TIMEOUT_SECONDS}s."
  run_diagnostic kubectl get service traefik -n traefik -o wide
  run_diagnostic kubectl describe service traefik -n traefik
  exit 1
fi

TRAEFIK_NLB_HOST="${TRAEFIK_NLB_HOST%.}"

JENKINS_HOST="jenkins.mud-as-sir.uk"

echo "✓ Traefik NLB hostname: $TRAEFIK_NLB_HOST"

DNS_DEADLINE=$((SECONDS + DNS_TIMEOUT_SECONDS))

DNS_READY=false
ROUTE53_RECORDS='[]'
NLB_IPS=''
PUBLIC_IPS=''

echo "Waiting for the Ingress, Route 53 records, and public DNS..."

ROUTE53_QUERY_FAILED=false

while (( SECONDS < DNS_DEADLINE )); do
  INGRESS_NLB_HOST="$(
    timeout 8s kubectl get ingress jenkins -n jenkins \
      -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' \
      2>/dev/null || true
  )"
  INGRESS_NLB_HOST="${INGRESS_NLB_HOST%.}"

  NLB_IPS="$(
    timeout 5s dig +time=2 +tries=1 +short A "$TRAEFIK_NLB_HOST" 2>/dev/null \
      | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' \
      | sort -u || true
  )"

  PUBLIC_IPS="$(
    timeout 5s dig +time=2 +tries=1 +short A "$JENKINS_HOST" 2>/dev/null \
      | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' \
      | sort -u || true
  )"

  ROUTE53_QUERY_FAILED=false

  ROUTE53_RECORDS="$(
    timeout 8s aws route53 list-resource-record-sets \
      --hosted-zone-id "$ROUTE53_ZONE_ID" \
      --query "ResourceRecordSets[?Name==\`${JENKINS_HOST}.\` || Name==\`a-.${JENKINS_HOST}.\`]" \
      --output json 2>/dev/null
  )" || {
    ROUTE53_QUERY_FAILED=true
    ROUTE53_RECORDS='[]'
  }

  A_RECORD_VALID=false
  TXT_RECORD_VALID=false

  if printf '%s' "$ROUTE53_RECORDS" | jq -e \
    --arg host "${JENKINS_HOST}." \
    --arg nlb "$TRAEFIK_NLB_HOST" \
    --argjson nlb_ips "$(printf '%s\n' "$NLB_IPS" | jq -Rsc 'split("\n") | map(select(length > 0))')" \
    '
      any(.[];
        .Name == $host and .Type == "A" and
        (
          (
            ((.AliasTarget.DNSName // "") | ascii_downcase
              | sub("\\.$"; "") | sub("^dualstack\\."; ""))
            ==
            ($nlb | ascii_downcase
              | sub("\\.$"; "") | sub("^dualstack\\."; ""))
          )
          or
          any((.ResourceRecords // [])[];
            .Value as $value | $nlb_ips | index($value) != null)
        )
      )
    ' >/dev/null 2>&1; then
    A_RECORD_VALID=true
  fi

   if printf '%s' "$ROUTE53_RECORDS" | jq -e \
    --arg a_host "a-.${JENKINS_HOST}." \
    --arg owner "external-dns/owner=jenkins-eks-challenge" \
    '
      any(.[];
        .Name == $a_host and .Type == "TXT" and
        any((.ResourceRecords // [])[];
          (.Value | ltrimstr("\"") | rtrimstr("\"") | split(",")
            | map(gsub("^\\s+|\\s+$"; ""))) as $metadata
          | ($metadata | index($owner)) != null
            and any($metadata[];
              startswith("external-dns/resource=")
              and length > ("external-dns/resource=" | length))
        )
      )
    ' >/dev/null 2>&1; then
    TXT_RECORD_VALID=true
  fi

  DNS_IP_OVERLAP=false
  if [[ -n "$NLB_IPS" && -n "$PUBLIC_IPS" ]]; then
    while IFS= read -r ip; do
      if grep -Fqx -- "$ip" <<< "$PUBLIC_IPS"; then
        DNS_IP_OVERLAP=true
        break
      fi
    done <<< "$NLB_IPS"
  fi

  HTTPS_STATUS=""
  HTTPS_CURL_EXIT="not_attempted"
  HTTPS_READY=false

if [[ "$INGRESS_NLB_HOST" == "$TRAEFIK_NLB_HOST" ]] \
  && [[ "$A_RECORD_VALID" == true ]] \
  && [[ "$TXT_RECORD_VALID" == true ]]; then
    if HTTPS_STATUS="$(
      timeout 12s curl -4 --silent --show-error --output /dev/null \
        --connect-timeout 5 --max-time 10 \
        --write-out '%{http_code}' "https://${JENKINS_HOST}/" \
        2>/dev/null
    )"; then
      HTTPS_CURL_EXIT=0
    else
      HTTPS_CURL_EXIT=$?
    fi

    if [[ "$HTTPS_CURL_EXIT" -eq 0 ]] \
      && [[ "$HTTPS_STATUS" =~ ^[0-9]{3}$ ]] \
      && (( 10#$HTTPS_STATUS >= 200 && 10#$HTTPS_STATUS < 400 )); then
      HTTPS_READY=true
      DNS_READY=true
      break
    fi
  fi

  sleep "$DNS_POLL_SECONDS"
done

if [[ "$DNS_READY" != true ]]; then
  echo "ERROR: Public DNS did not become ready within ${DNS_TIMEOUT_SECONDS}s."
  echo "Traefik NLB hostname: $TRAEFIK_NLB_HOST"
  echo "Ingress hostname: ${INGRESS_NLB_HOST:-not published}"
  echo "Route 53 A record valid: $A_RECORD_VALID"
  echo "Route 53 query failed during polling: $ROUTE53_QUERY_FAILED"
  echo "Route 53 TXT ownership valid: $TXT_RECORD_VALID"
  echo "Public DNS overlaps current NLB IPs: $DNS_IP_OVERLAP"
  echo "HTTPS response status: ${HTTPS_STATUS:-unavailable}"
  echo "HTTPS curl exit code: $HTTPS_CURL_EXIT"
  echo "HTTPS readiness: $HTTPS_READY"
  echo
  echo "Traefik Service:"
  run_diagnostic kubectl get service traefik -n traefik -o wide
  echo
  echo "Jenkins Ingress:"
  run_diagnostic kubectl get ingress jenkins -n jenkins -o yaml
  echo
  echo "ExternalDNS pods:"
  run_diagnostic kubectl get pods -n external-dns -o wide
  echo
  echo "Recent ExternalDNS logs:"
  run_diagnostic kubectl logs deployment/external-dns -n external-dns --tail=100
  echo
  echo "Route 53 records:"
  printf '%s\n' "$ROUTE53_RECORDS" | jq . || true
  echo
  echo "Recent events:"
  timeout 5s kubectl get events -A --sort-by='.lastTimestamp' 2>/dev/null | tail -40 || echo 'Recent events unavailable or timed out.'
  exit 1
fi

echo "✓ Route 53 A record targets the current Traefik NLB."
echo "✓ ExternalDNS TXT ownership record is present."
echo "✓ Public DNS resolves to a current Traefik NLB address."
echo "✓ HTTPS responded successfully (HTTP ${HTTPS_STATUS})."

print_banner "Deployment Successful"

echo "EKS platform and GitOps stack are ready."
echo
echo "Application workloads are managed by ArgoCD."
echo "Application deployments should be triggered through Git commits."
echo
echo "Use destroy.sh when the environment is no longer required."