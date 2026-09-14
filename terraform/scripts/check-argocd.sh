#!/usr/bin/env bash

set -euo pipefail

NAMESPACE="argocd"
OPTIONAL_MANUAL_APP="e-commerce-prod"

echo "====================================="
echo "ArgoCD Application Status"
echo "====================================="

if ! kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
  echo "ERROR: ArgoCD namespace '$NAMESPACE' is not available."
  exit 1
fi

APPLICATIONS="$(
  kubectl get applications.argoproj.io \
    -n "$NAMESPACE" \
    -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.sync.status}{"\t"}{.status.health.status}{"\n"}{end}' \
    | sort
)"

if [[ -z "$APPLICATIONS" ]]; then
  echo "ERROR: No ArgoCD Applications were found."
  exit 1
fi

printf '%-22s %-12s %-12s\n' "NAME" "SYNC STATUS" "HEALTH STATUS"
printf '%-22s %-12s %-12s\n' "----------------------" "------------" "------------"

FAILED=0

while IFS=$'\t' read -r NAME SYNC_STATUS HEALTH_STATUS; do
  printf '%-22s %-12s %-12s\n' \
    "$NAME" \
    "$SYNC_STATUS" \
    "$HEALTH_STATUS"

if [[ "$NAME" == "$OPTIONAL_MANUAL_APP" ]]; then
  continue
fi

if [[ "$NAME" == "platform-root" ]]; then
  if [[ "$HEALTH_STATUS" != "Healthy" ]]; then
    FAILED=1
  fi
  continue
fi

if [[ "$SYNC_STATUS" != "Synced" || "$HEALTH_STATUS" != "Healthy" ]]; then
  FAILED=1
fi
done <<< "$APPLICATIONS"

echo

if [[ "$FAILED" -ne 0 ]]; then
  echo "ERROR: One or more required ArgoCD Applications are not Synced and Healthy."
  exit 1
fi

echo "✓ All required ArgoCD Applications are Healthy."
echo "✓ e-commerce-prod is intentionally manual and may be OutOfSync."
echo "✓ platform-root may be OutOfSync when it reflects the manual production application."